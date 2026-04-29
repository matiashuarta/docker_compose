# iam.tf: IAM roles for EKS — replaces the single ECS execution role
#
# EKS needs two separate roles (ECS only needed one):
#   1. cluster role — allows the EKS control plane to manage AWS resources
#                     (create network interfaces, manage load balancers, etc.)
#   2. node role    — allows EC2 nodes to join the cluster, pull images, send logs

# ─── CLUSTER ROLE ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }  # EKS control plane assumes this role
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ─── NODE ROLE ────────────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_node" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }  # EC2 instances (nodes) assume this role
    }]
  })
}

# allows nodes to register with the EKS cluster and receive work
resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# allows the CNI plugin (VPC networking) to create and manage network interfaces for pods
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# allows nodes to pull images from ECR — also covers internet access to pull from GHCR
resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ─── CLUSTER AUTOSCALER POLICY ────────────────────────────────────────────────

# allows the Cluster Autoscaler pod to call AWS Auto Scaling APIs
# needed to add/remove EC2 nodes when pods are pending or nodes are underutilized
resource "aws_iam_policy" "cluster_autoscaler" {
  name = "ClusterAutoscalerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:DescribeInstanceTypes"
      ]
      Resource = ["*"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}
