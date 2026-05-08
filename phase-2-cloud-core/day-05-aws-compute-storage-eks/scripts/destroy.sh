#!/bin/bash
# EKS Cluster Destroy Script
# Run: bash destroy.sh
# Time: ~10-15 minutes
# After this: ZERO AWS charges (VPC/subnets/IGW are free)

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"
VPC_ID="vpc-0b3ef75987ebd61cf"

echo "=== Destroying EKS Cluster — Full Cleanup ==="
echo "Deletes: node group, cluster, all VPC interface endpoints"
echo "Keeps:   VPC, subnets, IGW, route tables, S3 gateway endpoint (all free)"
echo ""
read -p "Sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# Step 1: Delete node group first (cluster delete needs it gone)
echo ""
echo "[1/3] Deleting node group..."
aws eks delete-nodegroup \
  --profile $AWS_PROFILE \
  --region $REGION \
  --cluster-name $CLUSTER \
  --nodegroup-name devops-lab-node-group 2>/dev/null || echo "Node group not found — skipping"

echo "Waiting for node group deletion (~5 min)..."
aws eks wait nodegroup-deleted \
  --profile $AWS_PROFILE \
  --region $REGION \
  --cluster-name $CLUSTER \
  --nodegroup-name devops-lab-node-group 2>/dev/null || true

# Step 2: Delete cluster
echo ""
echo "[2/3] Deleting EKS cluster..."
aws eks delete-cluster \
  --profile $AWS_PROFILE \
  --region $REGION \
  --name $CLUSTER 2>/dev/null || echo "Cluster not found — skipping"

echo "Waiting for cluster deletion (~5 min)..."
aws eks wait cluster-deleted \
  --profile $AWS_PROFILE \
  --region $REGION \
  --name $CLUSTER 2>/dev/null || true

# Step 3: Delete all VPC interface endpoints (eksctl doesn't clean these when using existing VPC)
echo ""
echo "[3/3] Deleting VPC interface endpoints..."
ENDPOINT_IDS=$(aws ec2 describe-vpc-endpoints \
  --profile $AWS_PROFILE \
  --region $REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=vpc-endpoint-type,Values=Interface" "Name=vpc-endpoint-state,Values=available,pending" \
  --query "VpcEndpoints[*].VpcEndpointId" \
  --output text)

if [ -n "$ENDPOINT_IDS" ]; then
  aws ec2 delete-vpc-endpoints \
    --profile $AWS_PROFILE \
    --region $REGION \
    --vpc-endpoint-ids $ENDPOINT_IDS
  echo "Deleted endpoints: $ENDPOINT_IDS"
else
  echo "No interface endpoints found — skipping"
fi

echo ""
echo "=== DONE — Bill: ZERO ==="
echo ""
echo "Still exists (free):"
echo "  VPC:              $VPC_ID"
echo "  Subnets, IGW, Route Tables, Security Groups"
echo "  S3 Gateway Endpoint"
echo ""
echo "Spin up tomorrow: bash create.sh"
