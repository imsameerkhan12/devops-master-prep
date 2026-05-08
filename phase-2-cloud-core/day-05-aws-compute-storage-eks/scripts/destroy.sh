#!/bin/bash
# EKS Cluster Destroy Script
# Run: bash destroy.sh
# Time: ~10 minutes
# After this: ZERO AWS charges (VPC/subnets/IGW are free)

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"

echo "=== Deleting EKS Cluster + Node Group + VPC Endpoints ==="
echo "This will delete: cluster, node group, all VPC interface endpoints eksctl created"
echo ""
read -p "Sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

eksctl delete cluster \
  --profile $AWS_PROFILE \
  --region $REGION \
  --name $CLUSTER \
  --wait

echo ""
echo "=== Cluster deleted. ==="
echo "Remaining (free — keep karo):"
echo "  VPC: vpc-0b3ef75987ebd61cf"
echo "  Subnets, IGW, Route Tables, Security Groups"
echo "  S3 Gateway Endpoint (free)"
echo ""
echo "Bill: $0 going forward"
