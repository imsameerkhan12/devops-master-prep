# main.tf — modules call karo
# Ye file = "dev environment ka blueprint"

# Data source — existing AWS account info fetch karo
# Data source = read-only, kuch banata nahi — sirf padhta hai
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module — poora networking banao
module "vpc" {
  source = "../../modules/vpc"

  name         = "${var.cluster_name}-vpc"
  region       = var.aws_region
  cluster_name = var.cluster_name
  tags         = var.tags

  # Default values from module variables.tf use honge
  # Override karna ho toh yahan likho:
  # cidr = "10.1.0.0/16"
}

# EKS Module — cluster + node group + add-ons
module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # VPC module ke outputs yahan use ho rahe hain
  # Ye module composition hai — ek module ka output doosre ka input
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  node_instance_type = var.node_instance_type
  node_desired       = var.node_desired
  node_min           = 1
  node_max           = 1

  # IAM user ARN — data source se automatically fetch hogi
  admin_iam_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/sameer"

  tags = var.tags

  # EKS VPC ke baad bane — explicit dependency
  depends_on = [module.vpc]
}
