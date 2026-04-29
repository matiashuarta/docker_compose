#!/bin/bash
# setup-eks.sh: run this after terraform apply to deploy everything to EKS
# usage: bash setup-eks.sh

set -e

echo "==> Connecting kubectl to EKS cluster..."
aws eks update-kubeconfig --region us-east-1 --name docker-compose-app-cluster

echo "==> Getting RDS endpoint..."
RDS_ENDPOINT=$(cd terraform-eks && terraform output -raw rds_endpoint)

echo "==> Updating secret.yaml with RDS endpoint..."
sed -i "s|<RDS_ENDPOINT>|$RDS_ENDPOINT|" k8s/secret.yaml

echo "==> Creating AWS credentials secret for Cluster Autoscaler..."
kubectl create secret generic aws-credentials \
  --namespace kube-system \
  --from-literal=access-key-id=$(aws configure get aws_access_key_id) \
  --from-literal=secret-access-key=$(aws configure get aws_secret_access_key) \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/

echo "==> Done. Getting frontend URL..."
echo "Waiting for LoadBalancer IP (this takes ~2 minutes)..."
kubectl get service frontend -n app
