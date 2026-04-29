# outputs.tf: values printed after terraform apply
# most importantly: the kubeconfig command to connect kubectl to your cluster

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "rds_endpoint" {
  description = "RDS Postgres host — paste this into k8s/secret.yaml"
  value       = aws_db_instance.postgres.address
}

output "kubeconfig_command" {
  description = "Run this after terraform apply to configure kubectl on your machine"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
