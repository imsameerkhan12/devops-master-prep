#!/bin/bash
# EKS Full Infrastructure Destroy Script
# Destroys: manually created VPC endpoints + EKS cluster + node group + VPC (everything)
# Run: bash destroy.sh
# Time: ~10-15 minutes
# After this: ZERO AWS charges — everything gone

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"

echo "=== Destroying Full EKS Infrastructure ==="
echo "Deletes: sts/eks-auth endpoints, cluster, node group, VPC endpoints, VPC — everything"
echo ""
read -p "Sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# Step 1: Delete manually created VPC endpoints (sts + eks-auth)
# These were created by create.sh via AWS CLI — NOT managed by eksctl CloudFormation
# eksctl delete cluster will fail to delete VPC if these endpoints still exist
echo ""
echo "[1/2] Deleting manually created VPC endpoints (sts + eks-auth)..."

VPC_ID=$(aws eks describe-cluster --profile $AWS_PROFILE --region $REGION --name $CLUSTER \
  --query "cluster.resourcesVpcConfig.vpcId" --output text 2>/dev/null || true)

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
  echo "VPC: $VPC_ID"

  ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints --profile $AWS_PROFILE --region $REGION \
    --filters \
      "Name=vpc-id,Values=$VPC_ID" \
      "Name=service-name,Values=com.amazonaws.$REGION.sts,com.amazonaws.$REGION.eks-auth" \
      "Name=vpc-endpoint-state,Values=available,pending" \
    --query "VpcEndpoints[].VpcEndpointId" \
    --output text | tr '\t' ' ')

  if [ -n "$ENDPOINT_IDS" ]; then
    echo "Deleting endpoints: $ENDPOINT_IDS"
    aws ec2 delete-vpc-endpoints \
      --profile $AWS_PROFILE --region $REGION \
      --vpc-endpoint-ids $ENDPOINT_IDS
    echo "Waiting 15s for endpoint deletion to propagate..."
    sleep 15
  else
    echo "No orphaned endpoints found — nothing to delete"
  fi
else
  echo "Cluster not found or VPC already gone — skipping endpoint cleanup"
fi

# Step 2: eksctl delete cluster removes everything it created via CloudFormation:
# node group → cluster → VPC endpoints (eksctl ones) → subnets → IGW → route tables → VPC
echo ""
echo "[2/2] Deleting everything via eksctl (~10-15 min)..."
eksctl delete cluster \
  --profile $AWS_PROFILE \
  --region $REGION \
  --name $CLUSTER \
  --wait

echo ""
echo "=== DONE — Bill: ZERO ==="
echo "Everything deleted. Spin up fresh: bash create.sh"
