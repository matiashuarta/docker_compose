# eks.tf: the EKS cluster and node group — replaces ecs.tf entirely
#
# three concepts to understand (parallel to ECS):
#   Cluster    = the Kubernetes control plane managed by AWS (like the ECS cluster)
#   Node Group = EC2 instances where pods run (replaces Fargate — you now manage real servers)
#   Pod        = one or more containers running together (equivalent to an ECS task)
#
# key difference from ECS Fargate:
#   ECS Fargate  → AWS manages the servers, you pay per task CPU/RAM used
#   EKS nodes    → you pay for the EC2 instances 24/7 regardless of load
#
# cost warning: EKS control plane alone costs $0.10/hour (~$73/month)
# always run `terraform destroy` when done learning to stop charges

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    # control plane needs to know about both public and private subnets
    subnet_ids         = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# node group: the EC2 instances that actually run your pods
# managed node group = AWS handles OS updates and node replacement on failure
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn

  # nodes go in public subnets so they can reach GHCR to pull images
  subnet_ids = aws_subnet.public[*].id

  instance_types = [var.node_instance_type]  # t3.small — see variables.tf for why not t3.micro

  scaling_config {
    desired_size = 1  # 1 node is enough for learning — scale up for production
    min_size     = 1
    max_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy,
  ]
}
