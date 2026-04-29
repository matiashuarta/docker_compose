#!/bin/bash
# teardown-eks.sh: run this BEFORE terraform destroy
# Deletes Kubernetes-managed AWS resources (ELB, security groups) so they
# don't orphan inside the VPC and block terraform destroy.
#
# Usage:
#   bash teardown-eks.sh
#   cd terraform-eks && terraform destroy

set -e

echo "==> Connecting kubectl to EKS cluster..."
aws eks update-kubeconfig --region us-east-1 --name docker-compose-app-cluster

echo "==> Deleting frontend LoadBalancer service..."
echo "    (this triggers Kubernetes to remove the AWS ELB and its security group)"
kubectl delete service frontend -n app --ignore-not-found

echo "==> Waiting 30 seconds for AWS to remove the ELB..."
sleep 30

echo "==> Verifying ELB is gone..."
aws elb describe-load-balancers --region us-east-1 \
  --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text

echo ""
echo "==> Done. Now run:"
echo "    cd terraform-eks && terraform destroy"
