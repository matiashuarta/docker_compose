# security_groups.tf: firewall rules for each layer of the architecture
# each resource only accepts traffic from the layer directly in front of it
# this is the "principle of least privilege" applied to networking
#
# traffic flow:
# Internet → ALB (port 80) → Frontend (port 80)
#                           → Backend (port 8000)
#                                     → RDS (port 5432)

# ALB security group: the only thing exposed to the public internet
# accepts HTTP traffic from anywhere (0.0.0.0/0 = the entire internet)
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80            # accept traffic on port 80 (HTTP)
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # from anyone on the internet
  }

  egress {
    from_port   = 0             # allow all outbound traffic
    to_port     = 0
    protocol    = "-1"          # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# Frontend security group: only accepts traffic from the ALB, not directly from the internet
# this means users can't bypass the ALB and hit the container directly
resource "aws_security_group" "frontend" {
  name   = "${var.project_name}-frontend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80                             # nginx inside the container listens on 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # only from the ALB, not the internet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # can reach out to the internet (to call backend, pull images, etc.)
  }

  tags = { Name = "${var.project_name}-frontend-sg" }
}

# Backend security group: only accepts traffic from the ALB on port 8000 (uvicorn/FastAPI)
resource "aws_security_group" "backend" {
  name   = "${var.project_name}-backend-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8000                           # FastAPI/uvicorn listens on 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # only from the internal ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # can reach out (to connect to RDS, pull images, etc.)
  }

  tags = { Name = "${var.project_name}-backend-sg" }
}

# RDS security group: only accepts Postgres connections from the backend containers
# even if someone got into the VPC, they couldn't hit the DB unless they're the backend
resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432                               # standard Postgres port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]   # only from backend ECS tasks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}
