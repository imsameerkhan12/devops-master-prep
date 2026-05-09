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

# Step 1: Full infra — VPC + cluster + node group + add-ons + core endpoints
echo "[1/5] Creating VPC + EKS cluster + node group + add-ons (~15 min)..."
eksctl create cluster -f "$SCRIPT_DIR/cluster-config.yaml" --profile $AWS_PROFILE

# Step 2: Get VPC ID created by eksctl
echo ""
echo "[2/5] Fetching VPC info..."
VPC_ID=$(aws eks describe-cluster --profile $AWS_PROFILE --region $REGION --name $CLUSTER \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)
SG_ID=$(aws eks describe-cluster --profile $AWS_PROFILE --region $REGION --name $CLUSTER \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --profile $AWS_PROFILE --region $REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:aws:cloudformation:logical-id,Values=SubnetPrivate*" \
  --query "Subnets[*].SubnetId" --output text | tr '\t' ' ')
echo "VPC: $VPC_ID | SG: $SG_ID"

# Step 3: Add sts + eks-auth endpoints (needed for Pod Identity Agent)
echo ""
echo "[3/5] Adding sts + eks-auth VPC endpoints for Pod Identity..."
aws ec2 create-vpc-endpoint --profile $AWS_PROFILE --region $REGION \
  --vpc-id $VPC_ID --service-name com.amazonaws.$REGION.sts \
  --vpc-endpoint-type Interface --subnet-ids $SUBNET_IDS \
  --security-group-ids $SG_ID --private-dns-enabled \
  --query "VpcEndpoint.VpcEndpointId" --output text 2>/dev/null || echo "sts endpoint already exists"

aws ec2 create-vpc-endpoint --profile $AWS_PROFILE --region $REGION \
  --vpc-id $VPC_ID --service-name com.amazonaws.$REGION.eks-auth \
  --vpc-endpoint-type Interface --subnet-ids $SUBNET_IDS \
  --security-group-ids $SG_ID --private-dns-enabled \
  --query "VpcEndpoint.VpcEndpointId" --output text 2>/dev/null || echo "eks-auth endpoint already exists"

# Step 4: Configure kubectl + add access for sameer user
echo ""
echo "[4/5] Configuring kubectl..."
aws eks update-kubeconfig --profile $AWS_PROFILE --region $REGION --name $CLUSTER

aws eks create-access-entry \
  --profile $AWS_PROFILE --region $REGION --cluster-name $CLUSTER \
  --principal-arn "arn:aws:iam::${ACCOUNT}:user/sameer" \
  --type STANDARD 2>/dev/null || echo "Access entry already exists"

aws eks associate-access-policy \
  --profile $AWS_PROFILE --region $REGION --cluster-name $CLUSTER \
  --principal-arn "arn:aws:iam::${ACCOUNT}:user/sameer" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster 2>/dev/null || echo "Policy already associated"

# Step 5: Verify
echo ""
echo "[5/5] Verifying..."
export AWS_PROFILE=$AWS_PROFILE
kubectl get nodes
echo ""
kubectl get pods -n kube-system

echo ""
echo "=== Infrastructure Ready ==="
echo "Cost: ~\$0.10/hr (control plane) + ~\$0.047/hr (t3.medium)"
echo "Destroy everything: bash destroy.sh"
