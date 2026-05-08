#!/bin/bash
# EKS Cluster Create Script
# Run: bash create.sh
# Time: ~15-20 minutes

set -e  # stop on any error

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"
ACCOUNT="271169999916"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Creating EKS Cluster ==="
eksctl create cluster -f "$SCRIPT_DIR/cluster-config.yaml" --profile $AWS_PROFILE

echo ""
echo "=== Configuring kubectl ==="
aws eks update-kubeconfig --profile $AWS_PROFILE --region $REGION --name $CLUSTER

echo ""
echo "=== Adding kubectl Access for sameer IAM user ==="
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
echo "=== Verify ==="
kubectl get nodes
kubectl get pods -n kube-system

echo ""
echo "=== Done! Cluster ready. ==="
echo "Cost: ~\$0.10/hr (control plane) + ~\$0.047/hr (t3.medium node)"
echo "Delete when done: bash destroy.sh"
