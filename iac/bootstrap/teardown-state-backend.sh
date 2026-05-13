#!/bin/bash
# Teardown bootstrap resources — run AFTER tofu destroy completes.
# Deletes: S3 state bucket (all versions) + Docker Hub secret from Secrets Manager
# WARNING: State file will be gone — only run when you're fully done with this environment.

set -e

AWS_PROFILE="sameer"
REGION="us-east-1"
ACCOUNT=$(aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text)
BUCKET="devops-lab-tofu-state-${ACCOUNT}"
SECRET_NAME="ecr-pullthroughcache/docker-hub"

echo "=== Bootstrap Teardown ==="
echo "Bucket : s3://$BUCKET"
echo "Secret : $SECRET_NAME"
echo ""
echo "WARNING: This deletes the state file and Docker Hub secret permanently."
read -p "Type 'yes' to continue: " CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 1; }

# Delete all object versions (versioning = delete markers pile up)
echo ""
echo "--> Deleting all object versions from s3://$BUCKET..."
aws s3api list-object-versions \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output json | \
jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
while read args; do
  eval aws s3api delete-object --profile $AWS_PROFILE --bucket $BUCKET $args
done

# Delete all delete markers
echo "--> Deleting all delete markers..."
aws s3api list-object-versions \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
  --output json | \
jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
while read args; do
  eval aws s3api delete-object --profile $AWS_PROFILE --bucket $BUCKET $args
done

# Delete the bucket
echo "--> Deleting bucket s3://$BUCKET..."
aws s3api delete-bucket \
  --profile $AWS_PROFILE \
  --bucket $BUCKET \
  --region $REGION

# Delete Docker Hub secret
echo "--> Deleting Secrets Manager secret: $SECRET_NAME..."
aws secretsmanager delete-secret \
  --profile $AWS_PROFILE \
  --region $REGION \
  --secret-id $SECRET_NAME \
  --force-delete-without-recovery

echo ""
echo "=== Done — all bootstrap resources deleted ==="
