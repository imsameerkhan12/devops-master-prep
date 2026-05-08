#!/bin/bash
# EKS Full Infrastructure Destroy Script
# Destroys: EKS cluster + node group + VPC endpoints + VPC + subnets + IGW + route tables
# Run: bash destroy.sh
# Time: ~10-15 minutes
# After this: ZERO AWS charges — everything gone

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"

echo "=== Destroying Full EKS Infrastructure ==="
echo "Deletes: cluster, node group, VPC endpoints, VPC, subnets, IGW, route tables — everything"
echo ""
read -p "Sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# eksctl delete cluster removes EVERYTHING it created:
# node group → cluster → VPC endpoints → subnets → IGW → route tables → VPC
# One command — no orphaned resources
echo ""
echo "Deleting everything (~10-15 min)..."
eksctl delete cluster \
  --profile $AWS_PROFILE \
  --region $REGION \
  --name $CLUSTER \
  --wait

echo ""
echo "=== DONE — Bill: ZERO ==="
echo "Everything deleted. Spin up fresh tomorrow: bash create.sh"
