terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. Tạo VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                       = "devops-eks-vpc"
    "kubernetes.io/cluster/devops-eks-cluster" = "shared"
  }
}

# 2. Internet Gateway cho Public Subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "devops-eks-igw"
  }
}

# 3. Public Subnet (Cho Ingress / Load Balancer)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name                                       = "devops-eks-public-1a"
    "kubernetes.io/cluster/devops-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
}

# 4. Private Subnet (Cho Worker Nodes của K8s)
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name                                       = "devops-eks-private-1a"
    "kubernetes.io/cluster/devops-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

# 5. Elastic IP & NAT Gateway (Cho Private Subnet đi Internet)
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "devops-eks-nat-gw"
  }
}

# 6. Bảng định tuyến (Route Tables)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "devops-eks-public-rt" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "devops-eks-private-rt" }
}

# 7. Liên kết Route Table với Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}