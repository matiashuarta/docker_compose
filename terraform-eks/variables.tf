# variables.tf: same configurable values as the ECS version
# only addition is node_instance_type — EKS runs on real EC2 nodes, unlike ECS Fargate

variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "docker-compose-app"  # prefix for every AWS resource name
}

variable "frontend_image" {
  default = "ghcr.io/matiashuarta/docker_compose-frontend:latest"
}

variable "backend_image" {
  default = "ghcr.io/matiashuarta/docker_compose-backend:latest"
}

variable "db_username" {
  default = "app"
}

variable "db_password" {
  default   = "secret123"
  sensitive = true
}

variable "db_name" {
  default = "tasksdb"
}

variable "node_instance_type" {
  # t3.micro is too small — EKS system pods alone consume ~400MB RAM
  # t3.small (2GB) is the minimum that reliably fits system pods + your app pods
  default = "t3.small"
}
