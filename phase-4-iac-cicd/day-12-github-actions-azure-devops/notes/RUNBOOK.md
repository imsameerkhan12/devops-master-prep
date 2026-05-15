# Day 12 RUNBOOK — GitHub Actions CI/CD

Full lifecycle: one-time setup → create → destroy → recreate.

---

## One-Time Setup (Never Repeat)

### Step 1 — Create IAM user for CI

```bash
aws iam create-user --user-name github-actions-ci --profile sameer

aws iam attach-user-policy \
  --user-name github-actions-ci \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile sameer

aws iam create-access-key --user-name github-actions-ci --profile sameer
```

### Step 2 — Set GitHub Secrets + Variables

```bash
REPO="imsameerkhan12/devops-master-prep"

# Secrets (sensitive — never in git)
gh secret set AWS_ACCESS_KEY_ID       --repo $REPO --body "<from step 1>"
gh secret set AWS_SECRET_ACCESS_KEY   --repo $REPO --body "<from step 1>"
gh secret set DOCKER_HUB_USERNAME     --repo $REPO --body "imsameerkhan12"
gh secret set DOCKER_HUB_ACCESS_TOKEN --repo $REPO --body "<docker hub PAT>"

# Variables (non-sensitive)
gh variable set CLUSTER_NAME  --repo $REPO --body "devops-lab-eks"
gh variable set ECR_REGISTRY  --repo $REPO --body "271169999916.dkr.ecr.us-east-1.amazonaws.com"
# AWS_ROLE_ARN — set after first infra-apply (see below)
```

> These are permanent. Survive cluster destroy + recreate. Never redo unless rotating keys.

---

## Create Cluster

### Step 3 — Run infra-apply workflow

```bash
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
gh run watch --repo imsameerkhan12/devops-master-prep
```

Or: **GitHub → Actions → Infra Apply → Run workflow**

Takes ~17 min. Creates:
- S3 state bucket + Docker Hub secret in Secrets Manager (idempotent)
- VPC + subnets + S3 gateway endpoint (free, no interface endpoints)
- EKS cluster v1.33 + 2× t3.medium nodes + 6 add-ons
- ECR pull-through cache (docker-hub) + pre-created repos + lifecycle policies
- ECR repos for cert-manager (quay-io/jetstack/*)
- GitHub Actions OIDC provider + IAM role
- Pod Identity association for s3-reader app
- S3 bucket + test objects for s3-lister app

### Step 4 — Set AWS_ROLE_ARN variable (one-time after first apply)

From the "Print Outputs" step in workflow logs:

```bash
gh variable set AWS_ROLE_ARN --repo imsameerkhan12/devops-master-prep \
  --body "arn:aws:iam::271169999916:role/devops-lab-eks-github-actions"
```

> Same ARN every time tofu recreates it. Never update again.

---

## Install Platform Tools

### Step 5 — Run bootstrap workflow

```bash
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

Takes ~5-7 min. Installs in order:
1. Pre-push cert-manager images to ECR (quay.io → ECR, bootstrap runner has internet)
2. Gateway API CRDs v1.5.1
3. Traefik (NLB + Gateway API)
4. cert-manager v1.17.0 (TLS controller, images pulled from ECR)

> CI/CD uses GitHub-hosted runners (ubuntu-latest) — no self-hosted runner setup needed.

### Step 6 — Verify

```bash
# Traefik NLB URL
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# cert-manager running
kubectl get pods -n cert-manager

# Trigger CI
git commit --allow-empty -m "test CI" && git push
gh run list --repo imsameerkhan12/devops-master-prep --workflow CI
```

---

## Destroy (Full Cleanup)

### Option A — via destroy workflow (recommended)

```bash
gh workflow run destroy.yaml \
  --repo imsameerkhan12/devops-master-prep \
  --field confirm=destroy \
  --field destroy_state_bucket=false
```

- `destroy_state_bucket=false` → keeps state bucket, can recreate cluster
- `destroy_state_bucket=true` → full wipe including state

Takes ~10-12 min.

### Option B — manual (if workflow fails or cluster unreachable)

```bash
# 1. Uninstall Helm releases (Traefik must be last — it owns the NLB)
helm uninstall s3-lister    -n default      --ignore-not-found --wait 2>/dev/null || true
helm uninstall cert-manager -n cert-manager --ignore-not-found --wait 2>/dev/null || true
helm uninstall traefik      -n traefik      --ignore-not-found --wait 2>/dev/null || true

# 2. Wait for NLB to release
sleep 60

# 3. Delete any remaining NLBs
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?Type==`network`].LoadBalancerArn' --output text | \
  xargs -I{} aws elbv2 delete-load-balancer --load-balancer-arn {}

# 4. Destroy infra
cd iac/envs/dev
tofu init
tofu destroy -auto-approve -parallelism=20 --var-file=dev.tfvars --var='aws_profile='

# 5. Optional: teardown state bucket
bash iac/bootstrap/teardown-state-backend.sh --yes
```

### If destroy gets DependencyViolation on subnets

Root cause: VPC Interface Endpoints create ENIs in private subnets that block deletion.
The destroy workflow handles this automatically. For manual cleanup:

```bash
VPC_ID="<your-vpc-id>"

# Delete VPC endpoints first
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
  --query 'VpcEndpoints[*].VpcEndpointId' --output text | \
  xargs aws ec2 delete-vpc-endpoints --vpc-endpoint-ids

# Wait for ENIs to release (~2 min), then retry tofu destroy
```

---

## Recreate After Destroy

State bucket kept (`destroy_state_bucket=false`):
```bash
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
# wait ~17 min, then:
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

State bucket deleted:
```bash
# infra-apply.yaml creates the state bucket automatically before tofu init
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
```

---

## Workflow Reference

| Workflow | Trigger | Runner | Auth | What it does |
|---|---|---|---|---|
| `infra-apply.yaml` | push to `iac/**` or manual | ubuntu-latest | Static IAM creds | Creates state bucket + secret + tofu apply -parallelism=20 |
| `bootstrap.yaml` | manual only | ubuntu-latest | OIDC | Pre-push images to ECR + install Traefik + cert-manager |
| `destroy.yaml` | manual only | ubuntu-latest | Static IAM creds | Helm uninstalls + delete VPC endpoints + tofu destroy -parallelism=20 |
| `ci.yaml` | push/PR to `app/s3-lister/**` | ubuntu-latest | OIDC (deploy job) | lint job: helm lint + template; deploy job: helm upgrade |

---

## GitHub Repo Setup Reference

| Type | Name | Value | Rotate? |
|---|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` | IAM user key | If compromised |
| Secret | `AWS_SECRET_ACCESS_KEY` | IAM user secret | If compromised |
| Secret | `DOCKER_HUB_USERNAME` | `imsameerkhan12` | Never |
| Secret | `DOCKER_HUB_ACCESS_TOKEN` | Docker Hub PAT | If expired |
| Variable | `CLUSTER_NAME` | `devops-lab-eks` | Never |
| Variable | `ECR_REGISTRY` | `271169999916.dkr.ecr.us-east-1.amazonaws.com` | Never |
| Variable | `AWS_ROLE_ARN` | `arn:aws:iam::271169999916:role/devops-lab-eks-github-actions` | Never |

---

## Gotchas

| Problem | Cause | Fix |
|---|---|---|
| infra-apply fails: data source `ecr-pullthroughcache/docker-hub` not found | Secret doesn't exist yet | infra-apply creates it automatically before tofu init — check step ordering |
| bootstrap OIDC error | `AWS_ROLE_ARN` variable not set | Set it from infra-apply "Print Outputs" step logs |
| cert-manager pods ImagePullBackOff | quay.io images not pre-pushed to ECR | Re-run bootstrap — it pre-pushes before helm install |
| NLB never gets IP | `image.registry` not set for Traefik | Check bootstrap logs for `--set image.registry` |
| destroy: DependencyViolation on subnets | VPC Interface Endpoints have ENIs in subnets | destroy.yaml handles this automatically; manual fix above |
| `tofu destroy` fails after 3 attempts | New endpoint ENIs after previous partial destroy | Run destroy workflow again — it re-detects and deletes endpoints |
| Node group recreate → ECR 403 | IAM policies lost on recreation | Explicit `aws_iam_role_policy_attachment` in dev/main.tf (already fixed) |
| `Ec2SubnetInvalidConfiguration` on node group | Public subnets missing `map_public_ip_on_launch=true` | Already set in vpc/main.tf |
