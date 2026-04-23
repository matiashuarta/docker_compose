# rds.tf: managed Postgres database
# instead of running Postgres in a container (like your docker-compose setup),
# RDS handles backups, patching, and availability automatically

# subnet group: tells RDS which subnets it can use
# RDS requires at least 2 subnets in different AZs for high availability
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id  # [*] expands to all private subnets (both of them)
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-db"  # the name shown in the AWS console
  engine         = "postgres"
  engine_version = "16"                       # matches postgres:16 from your docker-compose

  instance_class    = "db.t3.micro"  # the cheapest RDS instance — 2 vCPU, 1GB RAM, free tier eligible
  allocated_storage = 20             # 20GB SSD disk

  db_name  = var.db_name      # tasksdb — the database to create on startup
  username = var.db_username  # app
  password = var.db_password  # secret123

  db_subnet_group_name   = aws_db_subnet_group.main.name           # place it in the private subnets
  vpc_security_group_ids = [aws_security_group.rds.id]             # apply the RDS firewall rules

  skip_final_snapshot = true   # when you destroy this DB, don't save a backup snapshot first
                                # set to false in production so you don't lose data on terraform destroy
  publicly_accessible = false  # NOT reachable from the internet — only from inside the VPC

  tags = { Name = "${var.project_name}-postgres" }
}
