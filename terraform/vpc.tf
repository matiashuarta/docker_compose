# vpc.tf: defines the private network where all your AWS resources live
# think of a VPC as your own isolated section of AWS — nothing gets in or out unless you allow it

# fetches the list of availability zones (AZs) in your region
# AZs are physically separate data centers within the same region
# us-east-1 has: us-east-1a, us-east-1b, us-east-1c, etc.
data "aws_availability_zones" "available" {
  state = "available"  # only return AZs that are currently online
}

# the VPC itself — your private network in AWS
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  # defines the IP range: 10.0.0.0 → 10.0.255.255 (65536 addresses)
  enable_dns_hostnames = true             # allows AWS to assign DNS names to resources (needed for RDS)
  enable_dns_support   = true             # enables DNS resolution within the VPC
  tags = { Name = "${var.project_name}-vpc" }
}

# internet gateway: the door between your VPC and the public internet
# without this, nothing in your VPC can reach or be reached from the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # attaches this gateway to our VPC
  tags   = { Name = "${var.project_name}-igw" }
}

# public subnets: subdivisions of the VPC where ECS tasks and ALBs live
# count=2 creates two subnets, one in each AZ — required for ALB (needs 2+ AZs for redundancy)
# map_public_ip_on_launch=true means resources here get a public IP automatically
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"  # subnet 1: 10.0.1.0/24, subnet 2: 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]  # spread across AZs
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-${count.index + 1}" }
}

# private subnets: where RDS lives — no direct internet access, more secure for databases
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 3}.0/24"  # subnet 1: 10.0.3.0/24, subnet 2: 10.0.4.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${var.project_name}-private-${count.index + 1}" }
}

# route table: defines where traffic goes when it leaves a subnet
# this rule says: anything going to 0.0.0.0/0 (the internet) → use the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"                    # all internet-bound traffic
    gateway_id = aws_internet_gateway.main.id   # goes through the internet gateway
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

# associates the route table with each public subnet
# without this, the route table exists but doesn't apply to any subnet
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
