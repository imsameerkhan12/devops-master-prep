#!/bin/bash
# App Teardown Script
# Deletes: K8s resources + Pod Identity Association + IAM Role + S3 bucket
# Run BEFORE: tofu destroy

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
CLUSTER="devops-lab-eks"
ACCOUNT=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
BUCKET="devops-lab-s3-lister-${ACCOUNT}"
ROLE_NAME="devops-lab-s3-reader"
NAMESPACE="default"
SERVICE_ACCOUNT="s3-reader-sa"

echo "=== App Teardown ==="
echo ""

# Step 1: K8s resources delete karo
echo "[1/4] Deleting K8s resources..."
kubectl delete -f app/s3-lister/ --ignore-not-found
kubectl delete namespace traefik --ignore-not-found

# Step 2: Pod Identity Association delete karo
echo ""
echo "[2/4] Deleting Pod Identity Association..."
ASSOC_ID=$(aws eks list-pod-identity-associations \
  --profile $AWS_PROFILE --region $REGION \
  --cluster-name $CLUSTER --namespace $NAMESPACE \
  --service-account $SERVICE_ACCOUNT \
  --query "associations[0].associationId" --output text 2>/dev/null || echo "")

if [ -n "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
  aws eks delete-pod-identity-association \
    --profile $AWS_PROFILE --region $REGION \
    --cluster-name $CLUSTER --association-id $ASSOC_ID
  echo "Association deleted"
else
  echo "No association found"
fi

# Step 3: IAM Role + policies delete karo
echo ""
echo "[3/4] Deleting IAM Role..."
aws iam detach-role-policy \
  --profile $AWS_PROFILE \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null || true

aws iam delete-role \
  --profile $AWS_PROFILE \
  --role-name $ROLE_NAME 2>/dev/null || echo "Role already deleted"

# Step 4: S3 bucket delete karo (pehle objects, phir bucket)
echo ""
echo "[4/4] Deleting S3 bucket..."
aws s3 rm s3://$BUCKET --recursive --profile $AWS_PROFILE 2>/dev/null || true
aws s3api delete-bucket \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --region $REGION 2>/dev/null || echo "Bucket already deleted"

echo ""
echo "=== App Teardown Complete ==="
echo "Now run: tofu destroy -var-file=dev.tfvars"
