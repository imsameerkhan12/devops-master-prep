#!/bin/bash
# EKS Full Infrastructure Destroy Script
# Destroys: manually created VPC endpoints + all eksctl CloudFormation stacks
# Run: bash destroy.sh
# Time: ~10-15 minutes
# After this: ZERO AWS charges — everything gone
#
# NOTE: Does NOT use `eksctl delete cluster` directly — private cluster K8s API
# is unreachable from outside VPC, causing eksctl to timeout on LB cleanup.
# Instead: deletes CF stacks directly in correct order (same end result).

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"
CLUSTER_STACK="eksctl-${CLUSTER}-cluster"

echo "=== Destroying Full EKS Infrastructure ==="
echo "Deletes: VPC endpoints + all CloudFormation stacks (cluster, nodegroup, addons, VPC)"
echo ""
read -p "Sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

# Step 1: Delete manually created VPC endpoints (sts + eks-auth)
# Not managed by eksctl CF — must delete before VPC deletion
echo ""
echo "[1/3] Deleting manually created VPC endpoints (sts + eks-auth)..."

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
    aws ec2 delete-vpc-endpoints --profile $AWS_PROFILE --region $REGION \
      --vpc-endpoint-ids $ENDPOINT_IDS
    echo "Waiting 15s for propagation..."
    sleep 15
  else
    echo "No orphaned endpoints found"
  fi
else
  echo "Cluster not found — skipping endpoint cleanup"
fi

# Step 2: Find all eksctl CF stacks for this cluster
echo ""
echo "[2/3] Deleting CloudFormation stacks..."

STACKS=$(aws cloudformation list-stacks --profile $AWS_PROFILE --region $REGION \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query "StackSummaries[?contains(StackName,'eksctl-${CLUSTER}')].StackName" \
  --output text | tr '\t' '\n')

if [ -z "$STACKS" ]; then
  echo "No stacks found — already deleted"
  echo ""
  echo "=== DONE — Bill: ZERO ==="
  exit 0
fi

echo "Stacks found:"
echo "$STACKS"
echo ""

# Disable termination protection on all stacks first
for stack in $STACKS; do
  aws cloudformation update-termination-protection --profile $AWS_PROFILE --region $REGION \
    --stack-name "$stack" --no-enable-termination-protection 2>/dev/null || true
done

# Delete addons + nodegroup stacks first (everything except cluster stack)
NON_CLUSTER_STACKS=$(echo "$STACKS" | grep -v "^${CLUSTER_STACK}$" || true)

if [ -n "$NON_CLUSTER_STACKS" ]; then
  for stack in $NON_CLUSTER_STACKS; do
    echo "Deleting: $stack"
    aws cloudformation delete-stack --profile $AWS_PROFILE --region $REGION --stack-name "$stack"
  done

  # Wait for all non-cluster stacks
  for stack in $NON_CLUSTER_STACKS; do
    while true; do
      STATUS=$(aws cloudformation describe-stacks --profile $AWS_PROFILE --region $REGION \
        --stack-name "$stack" --query "Stacks[0].StackStatus" --output text 2>&1)
      if [[ "$STATUS" =~ "does not exist" ]] || [[ "$STATUS" == "DELETE_COMPLETE" ]]; then
        echo "Deleted: $stack"
        break
      fi
      if [[ "$STATUS" == "DELETE_FAILED" ]]; then
        echo "ERROR: $stack deletion failed — check AWS Console"
        exit 1
      fi
      sleep 20
    done
  done
fi

# Delete cluster stack last (has VPC — must go after nodegroup + addons)
echo ""
echo "Deleting cluster stack (VPC + EKS control plane)..."
aws cloudformation delete-stack --profile $AWS_PROFILE --region $REGION --stack-name "$CLUSTER_STACK"

echo ""
echo "[3/3] Waiting for cluster stack deletion (~10 min)..."
while true; do
  STATUS=$(aws cloudformation describe-stacks --profile $AWS_PROFILE --region $REGION \
    --stack-name "$CLUSTER_STACK" --query "Stacks[0].StackStatus" --output text 2>&1)
  echo "$(date '+%H:%M:%S') — $STATUS"
  if [[ "$STATUS" =~ "does not exist" ]] || [[ "$STATUS" == "DELETE_COMPLETE" ]]; then
    break
  fi
  if [[ "$STATUS" == "DELETE_FAILED" ]]; then
    echo "ERROR: cluster stack deletion failed — check AWS Console"
    exit 1
  fi
  sleep 30
done

echo ""
echo "=== DONE — Bill: ZERO ==="
echo "Spin up fresh anytime: bash create.sh"
