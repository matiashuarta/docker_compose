# rds.tf: same managed Postgres as the ECS version — RDS doesn't care whether it's ECS or EKS
# the only difference is the security group: now allows traffic from EKS nodes instead of ECS tasks

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id  # RDS stays in private subnets — no internet access
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16"

  instance_class    = "db.t3.micro"  # cheapest RDS option — free tier eligible
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"
  publicly_accessible       = false

  tags = { Name = "${var.project_name}-postgres" }
}
