# alb.tf: Application Load Balancers
# an ALB sits in front of your ECS tasks and distributes traffic to healthy containers
# it also does health checks — if a container dies, the ALB stops sending it traffic
#
# we have two ALBs:
#   1. frontend ALB — public, internet-facing, users hit this directly
#   2. backend ALB  — internal, only reachable from inside the VPC

# ─── FRONTEND ALB ─────────────────────────────────────────────────────────────

resource "aws_lb" "frontend" {
  name               = "${var.project_name}-frontend-alb"
  internal           = false               # false = internet-facing (has a public DNS name)
  load_balancer_type = "application"       # ALB (vs network load balancer or gateway)
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id  # must span 2+ public subnets
  tags               = { Name = "${var.project_name}-frontend-alb" }
}

# target group: the pool of containers the ALB sends traffic to
# when ECS registers a new task, it adds its IP to this group automatically
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"  # "ip" is required for Fargate (vs "instance" for EC2)

  health_check {
    path                = "/"         # ALB will GET / to check if the container is healthy
    matcher             = "200-404"   # accept any of these status codes as "healthy"
    healthy_threshold   = 2           # need 2 successful checks to be considered healthy
    unhealthy_threshold = 3           # need 3 failures to be considered unhealthy
    interval            = 30          # check every 30 seconds
  }
}

# listener: the rule that says "when traffic arrives on port 80, send it to the target group"
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"                              # forward traffic (vs redirect, fixed response)
    target_group_arn = aws_lb_target_group.frontend.arn      # to the frontend containers
  }
}

# ─── BACKEND ALB (internal) ───────────────────────────────────────────────────

resource "aws_lb" "backend" {
  name               = "${var.project_name}-backend-alb"
  internal           = true   # true = private, only reachable from inside the VPC
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  tags               = { Name = "${var.project_name}-backend-alb" }
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg"
  port        = 8000          # FastAPI/uvicorn port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/docs"   # FastAPI auto-generates /docs — always returns 200 when healthy
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

# listener for backend ALB — listens on port 80 and forwards to backend containers on 8000
# the ALB translates: incoming port 80 → container port 8000
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
