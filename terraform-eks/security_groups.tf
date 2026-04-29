# security_groups.tf: firewall rules for EKS
#
# ECS had 4 security groups (ALB, frontend, backend, RDS)
# EKS simplifies this — Kubernetes handles internal pod-to-pod routing,
# so we only need rules for:
#   - control plane ↔ nodes communication
#   - nodes ↔ internet (to pull images from GHCR)
#   - nodes → RDS (port 5432)
#
# traffic flow:
#   Internet → AWS Load Balancer (created by k8s) → Nodes → Pods → RDS

# cluster security group: used by the EKS control plane
resource "aws_security_group" "eks_cluster" {
  name   = "${var.project_name}-eks-cluster-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-eks-cluster-sg" }
}

# node security group: firewall for the EC2 nodes
resource "aws_security_group" "eks_nodes" {
  name   = "${var.project_name}-eks-nodes-sg"
  vpc_id = aws_vpc.main.id

  # nodes need to talk to each other (pod-to-pod across nodes)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # control plane needs to reach nodes to schedule pods and check health
  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # allow public traffic into nodes on port 80 (for the LoadBalancer service)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # nodes need internet access to pull images
  }

  tags = { Name = "${var.project_name}-eks-nodes-sg" }
}

# RDS security group: accepts Postgres connections from anything inside the VPC
# using CIDR instead of eks_nodes SG because managed node groups create their
# own SG automatically — our custom eks_nodes SG is not attached to the nodes
resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # anything inside the VPC (nodes, pods, etc.)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}
