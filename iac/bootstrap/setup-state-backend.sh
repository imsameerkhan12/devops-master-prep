#!/bin/bash
# Run ONCE before any tofu commands.
# Creates S3 bucket for remote state + versioning + encryption.
# S3 native locking (use_lockfile = true) — no DynamoDB needed (OpenTofu 1.8+)

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
ACCOUNT=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
BUCKET="devops-lab-tofu-state-${ACCOUNT}"

echo "=== OpenTofu State Backend Setup ==="
echo "Bucket: s3://$BUCKET"
echo ""

# Create bucket
aws s3api create-bucket \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --region $REGION

# Versioning — allows rolling back to previous state
aws s3api put-bucket-versioning \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --versioning-configuration Status=Enabled

# Encryption at rest — state file has secrets (passwords, keys)
aws s3api put-bucket-encryption \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# Block all public access — state must NEVER be public
aws s3api put-public-access-block \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo ""
echo "=== Done ==="
echo "Now update iac/envs/dev/versions.tf:"
echo "  bucket = \"$BUCKET\""
