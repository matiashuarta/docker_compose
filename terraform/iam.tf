# iam.tf: Identity and Access Management — defines WHO can do WHAT in AWS
# ECS tasks need a role to perform actions like pulling images and writing logs
# without this role, the containers would start but fail silently

# creates the IAM role that ECS tasks will assume when they run
# "assume role" means: ECS is allowed to temporarily act as this role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-execution-role"

  # trust policy: defines WHO is allowed to assume this role
  # here we say: only the ECS tasks service can use this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"              # the action of "becoming" a role
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }  # only ECS tasks, not EC2, Lambda, etc.
    }]
  })
}

# attaches AWS's managed policy to our role
# AmazonECSTaskExecutionRolePolicy grants permission to:
#   - Pull Docker images from ECR (we use GHCR but the policy also covers network access)
#   - Write logs to CloudWatch (so our containers can output logs)
# managed policies are pre-built by AWS — you don't have to write the JSON yourself
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
