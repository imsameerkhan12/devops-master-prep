# Cluster Lifecycle
> Start · Stop · Verify · Destroy

---

## Quick Start

```bash
# Step 1 — Provision cluster (~17 min)
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
gh run watch --repo imsameerkhan12/devops-master-prep

# Step 2 — Install platform (~5-7 min)
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

## Destroy (always same day — $5-8/hr)

```bash
gh workflow run destroy.yaml --repo imsameerkhan12/devops-master-prep \
  --field confirm=destroy --field destroy_state_bucket=false
```

---

## Manual Provision (if workflow fails)

```powershell
$env:AWS_PROFILE = "sameer"
cd iac/envs/dev
tofu init
tofu --% plan -var-file=dev.tfvars -var="aws_profile=sameer"
tofu --% apply -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"

# Connect kubectl
aws eks update-kubeconfig --region us-east-1 --name devops-lab-eks --profile sameer
kubectl get nodes
```

## Manual Destroy (if workflow fails)

```powershell
helm uninstall s3-lister    -n default      --ignore-not-found
helm uninstall cert-manager -n cert-manager --ignore-not-found
helm uninstall traefik      -n traefik      --ignore-not-found

Start-Sleep 60   # Wait for NLB ENIs to release

cd iac/envs/dev
tofu --% destroy -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"
```

---

## Verify After Bootstrap

```bash
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get pods -n cert-manager
kubectl get pods -n default
```

---

## Destroy Order — Why It Matters

```
CORRECT ORDER:
  1. helm uninstall s3-lister
  2. helm uninstall cert-manager
  3. helm uninstall traefik          ← NLB DELETED HERE
  4. Sleep 60s                       ← NLB ENIs need ~60s to release
  5. tofu destroy
  6. teardown-state-backend.sh      ← LAST

WRONG (causes DependencyViolation):
  tofu destroy BEFORE helm uninstall traefik
  → NLB ENIs still in subnets → VPC deletion fails
```

---

## Port Forwards

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
kubectl port-forward -n argocd svc/argocd-server 8080:443
kubectl port-forward -n traefik $(kubectl get pods -n traefik -o name | head -1) 8080:8080
```

---

## Workflow Reference

| Workflow | Trigger | Auth | What |
|---|---|---|---|
| `infra-apply.yaml` | push `iac/**` or manual | Static IAM creds | tofu apply |
| `bootstrap.yaml` | manual | OIDC | Traefik + cert-manager |
| `destroy.yaml` | manual | Static IAM creds | Helm uninstall + tofu destroy |
| `ci.yaml` | push `app/s3-lister/**` | OIDC | helm lint + helm upgrade |
