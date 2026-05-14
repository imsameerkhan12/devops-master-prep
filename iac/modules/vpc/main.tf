# VPC Module
# Uses community terraform-aws-modules/vpc + adds VPC endpoints for private EKS

# Community module — handles VPC, subnets, IGW, route tables
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.19"

  name = var.name
  cidr = var.cidr
  azs  = var.azs

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # Nodes in public subnets need public IPs to reach github.com (required for ARC runners)
  map_public_ip_on_launch = true

  # No NAT Gateway — public subnets use IGW directly for internet access
  enable_nat_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags for EKS subnet auto-discovery (AWS LB Controller needs these)
  private_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${var.cluster_name}"   = "owned"
  })

  public_subnet_tags = merge(var.tags, {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${var.cluster_name}"   = "owned"
  })

  tags = var.tags
}

# Security Group for Interface VPC Endpoints
# Allows HTTPS (443) from within the VPC — endpoints speak HTTPS
resource "aws_security_group" "endpoints" {
  name_prefix = "${var.name}-endpoints-"
  description = "VPC endpoints - allow HTTPS from VPC CIDR"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-endpoints" })

  lifecycle {
    create_before_destroy = true
  }
}

# S3 Gateway Endpoint — FREE, no SG needed
# ECR image layers stored in S3 — nodes pull from here
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}

# Interface Endpoints — private cluster ke liye mandatory
# for_each = map (key = resource name, value = service suffix)
locals {
  interface_endpoints = {
    ec2      = "ec2"       # nodeadm bootstrap + VPC CNI ENI management
    ecr_api  = "ecr.api"   # container image metadata
    ecr_dkr  = "ecr.dkr"   # actual image pull
    eks      = "eks"       # K8s API
    sts      = "sts"       # token exchange (IRSA + internal)
    eks_auth = "eks-auth"  # Pod Identity Agent credentials
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}
