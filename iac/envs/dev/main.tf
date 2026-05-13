# main.tf — modules call karo
# Ye file = "dev environment ka blueprint"

# Data source — existing AWS account info fetch karo
# Data source = read-only, kuch banata nahi — sirf padhta hai
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# INFRASTRUCTURE LAYER
# ─────────────────────────────────────────────

# VPC Module — poora networking banao
module "vpc" {
  source = "../../modules/vpc"

  name         = "${var.cluster_name}-vpc"
  region       = var.aws_region
  cluster_name = var.cluster_name
  tags         = var.tags
}

# EKS Module — cluster + node group + add-ons
module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  node_instance_type = var.node_instance_type
  node_desired       = var.node_desired
  node_min           = 1
  node_max           = 1

  admin_iam_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/sameer"

  tags = var.tags

  depends_on = [module.vpc]
}

# ─────────────────────────────────────────────
# APP LAYER — AWS resources for s3-lister app
# K8s manifests (app/s3-lister/) kubectl se apply honge
# ─────────────────────────────────────────────

# S3 bucket — app list karega isko
resource "aws_s3_bucket" "app" {
  bucket        = "devops-lab-s3-lister-${data.aws_caller_identity.current.account_id}"
  force_destroy = true   # tofu destroy pe objects bhi delete ho jaayein

  tags = var.tags
}

# Test objects daalo — app ko kuch dikhane ke liye
resource "aws_s3_object" "hello" {
  bucket  = aws_s3_bucket.app.id
  key     = "hello.txt"
  content = "Hello from DevOps Lab — managed by OpenTofu"
}

resource "aws_s3_object" "pod_identity_test" {
  bucket  = aws_s3_bucket.app.id
  key     = "pod-identity-test.txt"
  content = "Pod Identity works — no hardcoded credentials!"
}

# IAM Role for s3-lister app — Pod Identity trust policy
resource "aws_iam_role" "s3_reader" {
  name = "${var.cluster_name}-s3-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "s3_reader" {
  role       = aws_iam_role.s3_reader.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Pod Identity Association — IAM Role ↔ K8s ServiceAccount link
# namespace = default, service_account = s3-reader-sa (app/s3-lister/serviceaccount.yaml)
resource "aws_eks_pod_identity_association" "s3_reader" {
  cluster_name    = module.eks.cluster_name
  namespace       = "default"
  service_account = "s3-reader-sa"
  role_arn        = aws_iam_role.s3_reader.arn

  depends_on = [module.eks]
}
