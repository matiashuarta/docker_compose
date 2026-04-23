# cloudwatch.tf: creates the log groups where container output will be stored
# when your ECS containers print anything (stdout/stderr), it goes here
# without these log groups, logs would have nowhere to go and containers might fail to start

# log group for the frontend container (nginx access logs, errors, etc.)
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}/frontend"  # path-style name, visible in CloudWatch console
  retention_in_days = 7   # automatically delete logs older than 7 days — keeps costs low while learning
}

# log group for the backend container (FastAPI request logs, Python errors, etc.)
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}/backend"
  retention_in_days = 7
}
