# VPC Module
# Uses community terraform-aws-modules/vpc + S3 gateway endpoint (free)

# Community module — handles VPC, subnets, IGW, route tables
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.19"

  name = var.name
  cidr = var.cidr
  azs  = var.azs

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # Nodes in public subnets — public IPs give direct internet via IGW, no NAT cost
  map_public_ip_on_launch = true

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

# S3 Gateway Endpoint — FREE, no SG needed
# Nodes in public subnets have internet via IGW — no interface endpoints needed.
# S3 gateway keeps ECR layer pulls (S3-backed) inside AWS network at no cost.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}
