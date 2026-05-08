#!/bin/bash
# EKS Full Infrastructure Create Script
# Creates: VPC + subnets + IGW + route tables + VPC endpoints + EKS cluster + node group + add-ons
# Run: bash create.sh
# Time: ~15-20 minutes

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"
ACCOUNT=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Creating Full EKS Infrastructure ==="
echo "Account: $ACCOUNT | Region: $REGION | Cluster: $CLUSTER"
echo ""

# Step 1: Full infra — VPC + cluster + node group + add-ons + endpoints
echo "[1/3] Creating VPC + EKS cluster + node group + add-ons (~15 min)..."
eksctl create cluster -f "$SCRIPT_DIR/cluster-config.yaml" --profile $AWS_PROFILE

# Step 2: Configure kubectl
echo ""
echo "[2/3] Configuring kubectl..."
aws eks update-kubeconfig --profile $AWS_PROFILE --region $REGION --name $CLUSTER

# Step 3: Grant kubectl access to sameer IAM user
echo ""
echo "[3/3] Adding EKS access for sameer IAM user..."
aws eks create-access-entry \
  --profile $AWS_PROFILE \
  --region $REGION \
  --cluster-name $CLUSTER \
  --principal-arn "arn:aws:iam::${ACCOUNT}:user/sameer" \
  --type STANDARD 2>/dev/null || echo "Access entry already exists — skipping"

aws eks associate-access-policy \
  --profile $AWS_PROFILE \
  --region $REGION \
  --cluster-name $CLUSTER \
  --principal-arn "arn:aws:iam::${ACCOUNT}:user/sameer" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster 2>/dev/null || echo "Policy already associated — skipping"

echo ""
echo "=== Infrastructure Ready ==="
kubectl get nodes
echo ""
kubectl get pods -n kube-system
echo ""
echo "Cost: ~\$0.10/hr (control plane) + ~\$0.047/hr (t3.medium)"
echo "Destroy everything: bash destroy.sh"
