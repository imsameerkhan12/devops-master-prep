# versions.tf — 2 kaam karta hai:
#   1. Required providers declare karo (kaunsa cloud, kaunsa version)
#   2. Backend config — state kahan rakho

terraform {
  required_version = ">= 1.8"  # use_lockfile needs 1.8+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state — S3 bucket mein store hoga
  # use_lockfile = true → S3 native locking, no DynamoDB needed
  backend "s3" {
    bucket       = "devops-lab-tofu-state-271169999916"  # bootstrap script se milega
    key          = "dev/terraform.tfstate"               # S3 path inside bucket
    region       = "us-east-1"
    encrypt      = true
    # use_lockfile = true  # OpenTofu 1.10+ needed — using 1.9.1
  }
}

# AWS provider config — region + profile
provider "aws" {
  region  = var.aws_region
  # Empty profile = use default credential chain (GitHub Actions OIDC, instance profile, etc.)
  profile = var.aws_profile != "" ? var.aws_profile : null
}
