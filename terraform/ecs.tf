# ecs.tf: the heart of the deployment
# ECS (Elastic Container Service) runs your Docker containers on AWS
# Fargate is the "serverless" mode — you don't manage any servers, AWS does
#
# three concepts to understand:
#   Cluster   = the logical group that contains your services (like a namespace)
#   Task Def  = the blueprint for a container (image, CPU, memory, env vars, ports, logs)
#   Service   = keeps N copies of a task running at all times, replaces failed tasks
#
# revision numbers: every time a task definition changes, AWS creates a new revision
# e.g. docker-compose-app-backend:1 → docker-compose-app-backend:2
# old revisions are kept so you can roll back if needed

# the cluster — just a logical container for your services, like a namespace
# all services and tasks below belong to this cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# ─── BACKEND ──────────────────────────────────────────────────────────────────

# task definition: the BLUEPRINT for the backend container
# this is never running by itself — the service below uses it to launch actual tasks
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"  # base name, AWS appends :1, :2 etc for revisions
  network_mode             = "awsvpc"                       # each task gets its own network interface (required for Fargate)
  requires_compatibilities = ["FARGATE"]                    # run on Fargate, not on EC2
  cpu                      = "256"                          # 0.25 vCPU — smallest unit, enough for this app
  memory                   = "512"                          # 512MB RAM
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn  # IAM role that allows pulling images and writing logs

  # container_definitions: JSON array describing what runs inside this task
  # in this case one container — the FastAPI backend
  container_definitions = jsonencode([{
    name  = "backend"
    image = var.backend_image  # ghcr.io/matiashuarta/docker_compose-backend:latest

    # tells ECS which port the container listens on
    # this is what the ALB target group forwards traffic to
    portMappings = [{
      containerPort = 8000  # uvicorn/FastAPI listens on 8000
      protocol      = "tcp"
    }]

    # environment variables injected into the container at runtime
    # replaces the DATABASE_URL from docker-compose
    # instead of pointing to the "db" container, it points to the RDS hostname
    environment = [{
      name  = "DATABASE_URL"
      value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:5432/${var.db_name}"
    }]

    # wires the container's stdout/stderr to CloudWatch
    # without this block, you'd have no logs to look at
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name  # /ecs/docker-compose-app/backend
        "awslogs-region"        = var.aws_region                          # must match your region
        "awslogs-stream-prefix" = "backend"                               # each task gets a stream like: backend/backend/<task-id>
      }
    }
  }])
}

# service: the RUNNING process that uses the task definition blueprint
# ensures desired_count=1 task is always running
# if the container crashes, ECS automatically starts a replacement
resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn  # points to the latest revision
  desired_count   = 1           # keep exactly 1 task running at all times
  launch_type     = "FARGATE"   # AWS manages the underlying server

  # networking: where the task runs and what firewall rules apply
  network_configuration {
    subnets          = aws_subnet.public[*].id            # which subnets the task can be placed in
    security_groups  = [aws_security_group.backend.id]    # firewall: only accept traffic from the ALB on port 8000
    assign_public_ip = true                               # needed to pull images from GHCR on startup
  }

  # registers this task's IP with the backend ALB target group
  # when the task starts, its IP is automatically added to the ALB pool
  # when it stops, it's automatically removed
  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8000
  }

  # dependency ordering: don't create this service until these resources exist
  # ALB listener must exist before tasks can register with it
  # RDS must be available before the backend can connect to the DB
  depends_on = [aws_lb_listener.backend, aws_db_instance.postgres]
}

# ─── FRONTEND ─────────────────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "frontend"
    image = var.frontend_image  # ghcr.io/matiashuarta/docker_compose-frontend:latest

    portMappings = [{
      containerPort = 80   # nginx inside the container serves on port 80
      protocol      = "tcp"
    }]

    # BACKEND_HOST tells nginx where to proxy /api/ requests
    # in docker-compose this was hardcoded to "backend" (resolved by Docker's internal DNS)
    # in ECS there is no internal DNS between containers, so we pass the internal ALB DNS name
    # nginx reads this via envsubst from default.conf.template on startup
    environment = [{
      name  = "BACKEND_HOST"
      value = aws_lb.backend.dns_name  # e.g. internal-docker-compose-app-backend-alb-xxx.us-east-1.elb.amazonaws.com
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name  # /ecs/docker-compose-app/frontend
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.frontend.id]  # only accepts traffic from the ALB on port 80
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  # frontend depends on the backend service being up first
  # so ECS starts backend → then frontend
  depends_on = [aws_lb_listener.frontend, aws_ecs_service.backend]
}
