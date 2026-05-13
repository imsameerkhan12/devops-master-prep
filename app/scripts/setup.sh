#!/bin/bash
# App Setup Script
# Creates: S3 bucket + test files + IAM role + Pod Identity Association
# Run AFTER: tofu apply (cluster must be up)
# Time: ~2 min

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"
ACCOUNT=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
BUCKET="devops-lab-s3-lister-${ACCOUNT}"
ROLE_NAME="devops-lab-s3-reader"
NAMESPACE="default"
SERVICE_ACCOUNT="s3-reader-sa"

echo "=== App Setup ==="
echo "Account: $ACCOUNT | Bucket: $BUCKET"
echo ""

# Step 1: S3 bucket banao + test files daalo
echo "[1/4] Creating S3 bucket + test files..."
aws s3api create-bucket \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --region $REGION 2>/dev/null || echo "Bucket already exists"

# Kuch test objects daalo taaki app kuch dikha sake
echo "Hello from DevOps Lab" | aws s3 cp - s3://$BUCKET/hello.txt --profile $AWS_PROFILE
echo "Pod Identity works!" | aws s3 cp - s3://$BUCKET/pod-identity-test.txt --profile $AWS_PROFILE
echo "S3 bucket ready with test files"

# Step 2: IAM Role banao (Pod Identity trust policy)
echo ""
echo "[2/4] Creating IAM Role for Pod Identity..."
aws iam create-role \
  --profile $AWS_PROFILE \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "pods.eks.amazonaws.com" },
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    }]
  }' 2>/dev/null || echo "Role already exists"

# S3 read policy attach karo
aws iam attach-role-policy \
  --profile $AWS_PROFILE \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null || echo "Policy already attached"

ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}"
echo "Role: $ROLE_ARN"

# Step 3: Pod Identity Association banao
# Links IAM Role ↔ K8s ServiceAccount (namespace + SA name)
echo ""
echo "[3/4] Creating Pod Identity Association..."
aws eks create-pod-identity-association \
  --profile $AWS_PROFILE \
  --region $REGION \
  --cluster-name $CLUSTER \
  --namespace $NAMESPACE \
  --service-account $SERVICE_ACCOUNT \
  --role-arn $ROLE_ARN 2>/dev/null || echo "Association already exists"

echo "Pod Identity Association: $NAMESPACE/$SERVICE_ACCOUNT → $ROLE_NAME"

# Step 4: S3 bucket name env var export (kubectl apply ke liye)
echo ""
echo "[4/4] Setup complete!"
echo ""
echo "Next steps:"
echo "  export S3_BUCKET=$BUCKET"
echo "  kubectl apply -f app/s3-lister/"
echo "  kubectl get pods -w"
