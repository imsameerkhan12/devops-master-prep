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

  tags = var.tags

  depends_on = [module.vpc]
}

# ─────────────────────────────────────────────
# ECR LAYER — Container Image Registry
# ─────────────────────────────────────────────

# Docker Hub credentials — Secrets Manager mein store kiya (manually)
# IaC ke bahar banaya intentionally — credentials IaC state mein nahi honi chahiye
# Data source = read-only reference, kuch nahi banata
data "aws_secretsmanager_secret" "docker_hub" {
  name = "ecr-pullthroughcache/docker-hub"
}

# Pull-Through Cache — Docker Hub mirror in private ECR
# Nodes pull from ECR (via ecr.dkr VPC endpoint) — no internet/NAT needed
# credential_arn = Docker Hub auth — no rate limits, authenticated pulls
resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  ecr_repository_prefix = "docker-hub"
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = data.aws_secretsmanager_secret.docker_hub.arn
}

# Node group role ko pull-through cache permission do
# BatchImportUpstreamImage = upstream se image fetch + cache karo
# CreateRepository = ECR mein naya repo auto-create karo (first pull pe)
resource "aws_iam_role_policy" "node_ecr_pull_through" {
  name = "ecr-pull-through-cache"
  role = module.eks.node_group_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:BatchImportUpstreamImage",  # upstream se cache mein import karo
        "ecr:CreateRepository",          # first pull pe repo auto-create
      ]
      Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/docker-hub/*"
    }]
  })
}

# Pre-create ECR repos — lifecycle policy attach karne ke liye repo exist karna chahiye
# Pull-through cache auto-creates repos on first pull, but we need them earlier for lifecycle
resource "aws_ecr_repository" "docker_hub_aws_cli" {
  name                 = "docker-hub/amazon/aws-cli"
  image_tag_mutability = "MUTABLE"
  force_delete         = true   # destroy pe delete ho

  image_scanning_configuration {
    scan_on_push = true   # security CVE scan on every push
  }

  tags       = var.tags
  depends_on = [aws_ecr_pull_through_cache_rule.docker_hub]
}

resource "aws_ecr_repository" "docker_hub_nginx" {
  name                 = "docker-hub/library/nginx"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags       = var.tags
  depends_on = [aws_ecr_pull_through_cache_rule.docker_hub]
}

resource "aws_ecr_repository" "docker_hub_traefik" {
  name                 = "docker-hub/library/traefik"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags       = var.tags
  depends_on = [aws_ecr_pull_through_cache_rule.docker_hub]
}

# ECR Lifecycle Policy — purani images clean karo automatically
# Production best practice: storage cost control + security (old CVE images)
locals {
  ecr_lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 3 tags only"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "docker_hub_aws_cli" {
  repository = aws_ecr_repository.docker_hub_aws_cli.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "docker_hub_nginx" {
  repository = aws_ecr_repository.docker_hub_nginx.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "docker_hub_traefik" {
  repository = aws_ecr_repository.docker_hub_traefik.name
  policy     = local.ecr_lifecycle_policy
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
