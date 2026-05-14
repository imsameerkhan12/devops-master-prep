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
  node_subnet_ids    = module.vpc.public_subnets  # public → nodes get internet → ARC can reach github.com

  node_instance_type = var.node_instance_type
  node_desired       = var.node_desired
  node_min           = 1
  node_max           = 1

  tags = var.tags

  depends_on = [module.vpc]
}

# Node group IAM policy attachments — managed explicitly so they survive partial-failed applies
# Community module's iam_role_additional_policies can get lost when node group is recreated mid-apply
resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = module.eks.node_group_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = module.eks.node_group_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  role       = module.eks.node_group_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
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

# ─────────────────────────────────────────────
# ECR LAYER — Plain repos for ARC + ArgoCD + cert-manager images
# Images pushed here by bootstrap workflow (GitHub-hosted runner has internet)
# No pull-through cache needed — ghcr.io/quay.io require credentials for that
# ─────────────────────────────────────────────

# ARC images
resource "aws_ecr_repository" "ghcr_actions_runner" {
  name                 = "ghcr-io/actions/actions-runner"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}

resource "aws_ecr_repository" "ghcr_arc_controller" {
  name                 = "ghcr-io/actions/gha-runner-scale-set-controller"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}

# docker-hub pull-through cache handles redis automatically
resource "aws_ecr_repository" "docker_hub_redis" {
  name                 = "docker-hub/library/redis"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags       = var.tags
  depends_on = [aws_ecr_pull_through_cache_rule.docker_hub]
}

# cert-manager images
resource "aws_ecr_repository" "quay_cert_manager_controller" {
  name                 = "quay-io/jetstack/cert-manager-controller"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}

resource "aws_ecr_repository" "quay_cert_manager_cainjector" {
  name                 = "quay-io/jetstack/cert-manager-cainjector"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}

resource "aws_ecr_repository" "quay_cert_manager_webhook" {
  name                 = "quay-io/jetstack/cert-manager-webhook"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}

resource "aws_ecr_repository" "quay_cert_manager_startupapicheck" {
  name                 = "quay-io/jetstack/cert-manager-startupapicheck"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}

# Lifecycle policies for all new repos (reuse existing local)
resource "aws_ecr_lifecycle_policy" "ghcr_actions_runner" {
  repository = aws_ecr_repository.ghcr_actions_runner.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "ghcr_arc_controller" {
  repository = aws_ecr_repository.ghcr_arc_controller.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "docker_hub_redis" {
  repository = aws_ecr_repository.docker_hub_redis.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "quay_cert_manager_controller" {
  repository = aws_ecr_repository.quay_cert_manager_controller.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "quay_cert_manager_cainjector" {
  repository = aws_ecr_repository.quay_cert_manager_cainjector.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "quay_cert_manager_webhook" {
  repository = aws_ecr_repository.quay_cert_manager_webhook.name
  policy     = local.ecr_lifecycle_policy
}

resource "aws_ecr_lifecycle_policy" "quay_cert_manager_startupapicheck" {
  repository = aws_ecr_repository.quay_cert_manager_startupapicheck.name
  policy     = local.ecr_lifecycle_policy
}

# ─────────────────────────────────────────────
# CI/CD LAYER — GitHub Actions OIDC
# No long-lived credentials — OIDC = short-lived tokens per workflow run
# ─────────────────────────────────────────────

# Fetch GitHub's OIDC certificate dynamically (avoids hardcoding thumbprint)
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

# OIDC provider — trust GitHub Actions JWT tokens
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

# IAM Role — GitHub Actions workflows assume this via OIDC
# Condition: only imsameerkhan12 repos can assume (not any GitHub repo)
resource "aws_iam_role" "github_actions" {
  name = "${var.cluster_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:imsameerkhan12/*:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

# ECR Power User — build + push images from CI
resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# EKS describe — update-kubeconfig + helm installs in bootstrap workflow
resource "aws_iam_role_policy" "github_actions_eks" {
  name = "eks-access"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters"]
        Resource = "*"
      },
      {
        # tofu destroy needs these to clean up load balancers before VPC deletion
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:DescribeLoadBalancers", "elasticloadbalancing:DeleteLoadBalancer"]
        Resource = "*"
      }
    ]
  })
}

# EKS Access Entry — GitHub Actions role gets cluster-admin (for bootstrap + destroy)
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  type          = "STANDARD"
  depends_on    = [module.eks]
}

resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.github_actions]
}
