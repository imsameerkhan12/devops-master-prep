#!/usr/bin/env bash
# app/deploy.sh — apps deploy karo (IaC apply ke baad chalao)
# Usage: bash app/deploy.sh <aws-account-id> <aws-region>
# Example: bash app/deploy.sh 271169999916 us-east-1

set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <account-id> <region>}"
REGION="${2:?Usage: $0 <account-id> <region>}"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "==> Step 1: Gateway API CRDs v1.5.1 install karo"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml

echo "==> Step 2: Traefik Helm install/upgrade karo"
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update traefik

# Image registry apne account ID se update karo values.yaml se before install
# Ya direct --set se override karo
helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace \
  -f app/traefik/values.yaml \
  --set "image.registry=${ECR_REGISTRY}" \
  --wait --timeout=3m

echo "==> Step 3: s3-lister Helm install/upgrade karo"
helm upgrade --install s3-lister app/s3-lister/chart \
  -n default \
  --set "image.init=${ECR_REGISTRY}/docker-hub/amazon/aws-cli:latest" \
  --set "image.nginx=${ECR_REGISTRY}/docker-hub/library/nginx:alpine" \
  --set "gateway.create=false" \
  --wait --timeout=3m

echo "==> Done. App URL:"
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
