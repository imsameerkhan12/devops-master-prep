# Day 12 RUNBOOK — GitHub Actions + ARC + ArgoCD

Full lifecycle: one-time setup → create → destroy → recreate.

---

## One-Time Setup (Never Repeat)

### Step 1 — Create IAM user for CI

```bash
# Create user
aws iam create-user --user-name github-actions-ci --profile sameer

# Admin access (scope down in real prod)
aws iam attach-user-policy \
  --user-name github-actions-ci \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile sameer

# Create access key — note the output
aws iam create-access-key --user-name github-actions-ci --profile sameer
```

### Step 2 — Create GitHub App for ARC

1. github.com → Settings → Developer settings → GitHub Apps → New GitHub App
2. Name: `devops-lab-arc` | Homepage: `https://github.com/imsameerkhan12`
3. **Uncheck Webhook Active**
4. Permissions:
   - **Actions: Read & Write**
   - **Administration: Read & Write** ← REQUIRED for runner registration (easy to miss)
   - **Metadata: Read-only** (mandatory, auto-selected)
5. Click Create → note **App ID** (3710409)
6. Generate private key → downloads `.pem`
7. Install App on the repo → note **Installation ID** from URL (132252489)

> **githubConfigUrl must be REPO-level for personal accounts:**
> `https://github.com/imsameerkhan12/devops-master-prep` — NOT user-level URL.
> Org accounts can use org-level URL. Personal accounts: repo-level only.

### Step 3 — Set GitHub Secrets + Variables (via gh CLI or UI)

```bash
REPO="imsameerkhan12/devops-master-prep"

# Secrets (sensitive — never in git)
gh secret set AWS_ACCESS_KEY_ID         --repo $REPO --body "<from step 1>"
gh secret set AWS_SECRET_ACCESS_KEY     --repo $REPO --body "<from step 1>"
gh secret set DOCKER_HUB_USERNAME       --repo $REPO --body "imsameerkhan12"
gh secret set DOCKER_HUB_ACCESS_TOKEN   --repo $REPO --body "<docker hub PAT>"
gh secret set ARC_GITHUB_APP_PRIVATE_KEY --repo $REPO --body "$(cat ~/Downloads/devops-lab-arc.*.pem)"

# Variables (non-sensitive)
gh variable set CLUSTER_NAME  --repo $REPO --body "devops-lab-eks"
gh variable set ECR_REGISTRY  --repo $REPO --body "271169999916.dkr.ecr.us-east-1.amazonaws.com"
# AWS_ROLE_ARN — set after first infra-apply (see below)
```

> These are permanent. Survive cluster destroy + recreate. Never redo unless rotating keys.

---

## Create Cluster

### Step 4 — Run infra-apply workflow

```bash
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep

# Watch progress
gh run watch --repo imsameerkhan12/devops-master-prep
```

Or: **GitHub → Actions → Infra Apply → Run workflow → Run**

Takes ~15 min. Creates:
- S3 state bucket (automatic, idempotent)
- Docker Hub secret in Secrets Manager (automatic, idempotent)
- VPC + private subnets + VPC endpoints
- EKS cluster (1x t3.medium node)
- ECR pull-through caches (docker-hub, ghcr-io, quay-io)
- ECR repos (pre-created to prevent orphans)
- GitHub Actions OIDC provider + IAM role
- EKS access entry for GitHub Actions role
- Pod Identity association for s3-reader

### Step 5 — Set AWS_ROLE_ARN variable (one-time after first apply)

From workflow logs, copy the role ARN printed in "Print Outputs" step:

```bash
gh variable set AWS_ROLE_ARN --repo imsameerkhan12/devops-master-prep \
  --body "arn:aws:iam::271169999916:role/devops-lab-eks-github-actions"
```

> Same ARN every time tofu recreates it (same account + same role name). Never update again.

---

## Install Platform Tools

### Step 6 — Run bootstrap workflow

```bash
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

Or: **GitHub → Actions → Bootstrap Platform → Run workflow → Run**

Takes ~8-10 min. Installs in order:
1. Gateway API CRDs v1.5.1
2. Traefik (NLB + Gateway API, via ECR pull-through for docker.io images)
3. ARC Controller (arc-systems namespace, image pre-pushed to ECR by bootstrap)
4. ARC GitHub App Secret (arc-runners namespace, from GitHub Secret)
5. ARC RunnerSet (scale 0→5, ephemeral pods, pulls runner image from ghcr.io directly)
6. cert-manager (TLS controller, cert-manager namespace)

> ArgoCD dropped — too heavy for t3.medium (4GB RAM). CI/CD via ARC push model instead.

### Step 7 — Verify

```bash
# Traefik NLB URL
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# ARC listener connected (should be Running)
kubectl get pods -n arc-systems

# ARC scale-to-zero — no pods when idle is CORRECT
kubectl get pods -n arc-runners   # "No resources found" = healthy

# cert-manager running
kubectl get pods -n cert-manager

# Trigger CI to test ARC runner:
git commit --allow-empty -m "test ARC runner" -- app/s3-lister/chart/Chart.yaml
git push
gh run list --repo imsameerkhan12/devops-master-prep --workflow CI
```

**Verify ARC works:** push any change to `app/s3-lister/**` → CI workflow triggers → ARC spawns runner pod → helm deploy runs.

---

## Gotchas

| Problem | Cause | Fix |
|---|---|---|
| bootstrap fails with OIDC error | AWS_ROLE_ARN variable not set | Set it from infra-apply logs |
| ARC listener running but no runners in GitHub Settings | githubConfigUrl is user-level, not repo-level | Change to `https://github.com/USER/REPO` in runner-values.yaml, re-run bootstrap |
| ARC listener running but no runners in GitHub Settings | GitHub App missing Administration: R+W | Update App permissions → accept in installation → re-run bootstrap |
| ARC runner pod: ErrImagePull 403 from ECR | Kubelet ECR credential cache poisoned at boot | Runner uses ghcr.io direct (already fixed); in prod: replace node |
| ARC EphemeralRunner: "Pod has failed to start more than 5 times" | IP exhaustion on t3.medium (17-pod limit) | Prefix delegation enabled in IaC; ensure `tofu apply` ran after that commit |
| ARC runner exits code 0 in <1 second, empty logs | JIT token already consumed by previous failed attempt | Delete stale EphemeralRunner: `kubectl delete ephemeralrunner -n arc-runners --all` |
| Node group recreate → ECR 403 / missing policies | Community module iam_role_additional_policies lost on recreation | Explicit `aws_iam_role_policy_attachment` resources in dev/main.tf (already fixed) |
| `Ec2SubnetInvalidConfiguration` on node group create | Public subnets missing map_public_ip_on_launch=true | Set in VPC module (already fixed in IaC) |
| cert-manager webhook CrashLoopBackOff | quay.io images not pre-pushed to ECR yet | Re-run bootstrap — it pre-pushes images before helm install |
| NLB never gets IP | Traefik image.registry not set | Check bootstrap logs for --set image.registry |
| destroy workflow 403 on S3 state bucket | OIDC role missing S3 permissions | destroy.yaml now uses static creds (already fixed); S3 perms also added to OIDC role in IaC |

---

## Destroy (Full Cleanup)

### Option A — via destroy workflow (recommended)

```bash
gh workflow run destroy.yaml \
  --repo imsameerkhan12/devops-master-prep \
  --field confirm=destroy \
  --field destroy_state_bucket=false
```

Or: **GitHub → Actions → Destroy Infrastructure → Run workflow**
- Type `destroy` in confirm field
- `destroy_state_bucket`: false = keep state bucket (can recreate cluster)
- `destroy_state_bucket`: true = delete everything including state (full wipe)

Takes ~12 min.

### Option B — manual (if workflow can't reach cluster)

```bash
# 1. Uninstall in order (MUST uninstall Traefik before tofu destroy)
kubectl delete application s3-lister -n argocd --ignore-not-found
helm uninstall s3-lister     -n default       --ignore-not-found
helm uninstall argocd        -n argocd        --ignore-not-found
helm uninstall cert-manager  -n cert-manager  --ignore-not-found
helm uninstall arc-runner-set -n arc-runners  --ignore-not-found
helm uninstall arc-controller -n arc-systems  --ignore-not-found
helm uninstall traefik       -n traefik       --ignore-not-found

# 2. Wait for NLB to be released
sleep 60

# 3. Verify NLB gone
aws elbv2 describe-load-balancers --profile sameer \
  --query "LoadBalancers[?contains(LoadBalancerName,'k8s')].LoadBalancerArn"

# 4. tofu destroy
cd iac/envs/dev
tofu destroy --var-file=dev.tfvars   # profile = sameer (from dev.tfvars)

# 5. Optional: teardown state bucket
bash iac/bootstrap/teardown-state-backend.sh
```

---

## Recreate After Destroy

If state bucket was NOT deleted:
```bash
# Just re-run both workflows — everything is automated
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
# wait ~15 min, then:
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

If state bucket WAS deleted:
```bash
# Re-run setup-state-backend.sh first, then infra-apply
bash iac/bootstrap/setup-state-backend.sh
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
```

---

## Workflow Reference

| Workflow | Trigger | Auth | What it does |
|---|---|---|---|
| `infra-apply.yaml` | push to `iac/**` or manual | Static IAM creds | Creates state bucket + Secrets Manager secret + tofu apply |
| `bootstrap.yaml` | manual only | OIDC | Pre-push images to ECR + install Traefik + ARC + cert-manager |
| `destroy.yaml` | manual only | Static IAM creds | Helm uninstalls + tofu destroy + optional state cleanup |
| `ci.yaml` | push to `app/s3-lister/**` or PR | ARC runner (self-hosted) | Helm lint + validate; on main: helm upgrade deploy |

---

## GitHub Repo Setup Reference

| Type | Name | Value | Rotate? |
|---|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` | IAM user key | If compromised |
| Secret | `AWS_SECRET_ACCESS_KEY` | IAM user secret | If compromised |
| Secret | `DOCKER_HUB_USERNAME` | `imsameerkhan12` | Never |
| Secret | `DOCKER_HUB_ACCESS_TOKEN` | Docker Hub PAT | If expired |
| Secret | `ARC_GITHUB_APP_PRIVATE_KEY` | `.pem` file content | If revoked |
| Variable | `CLUSTER_NAME` | `devops-lab-eks` | Never |
| Variable | `ECR_REGISTRY` | `271169999916.dkr.ecr.us-east-1.amazonaws.com` | Never |
| Variable | `AWS_ROLE_ARN` | `arn:aws:iam::271169999916:role/devops-lab-eks-github-actions` | Never |
