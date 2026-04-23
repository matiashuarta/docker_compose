# variables.tf: central place to define all configurable values
# instead of hardcoding values across multiple files, we reference var.something
# to change any value, you only need to edit it here

variable "aws_region" {
  default = "us-east-1"   # N. Virginia — the region where all resources will be created
}

variable "project_name" {
  default = "docker-compose-app"  # used as a prefix in every resource name (e.g. docker-compose-app-vpc)
}

variable "frontend_image" {
  # full image path from GitHub Container Registry
  # ECS will pull this image when starting the frontend container
  default = "ghcr.io/matiashuarta/docker_compose-frontend:latest"
}

variable "backend_image" {
  # same as above but for the FastAPI backend
  default = "ghcr.io/matiashuarta/docker_compose-backend:latest"
}

variable "db_username" {
  default = "app"   # Postgres username — same as POSTGRES_USER in your .env
}

variable "db_password" {
  default   = "secret123"  # Postgres password — same as POSTGRES_PASSWORD in your .env
  sensitive = true          # sensitive=true means Terraform will never print this value in logs or plan output
}

variable "db_name" {
  default = "tasksdb"  # the database name — same as POSTGRES_DB in your .env
}
