# Day 11 — Lab Runbook

Complete create and destroy steps for the devops-lab environment.
Run all commands from the **repo root** unless noted otherwise.

---

## Prerequisites (One-Time Setup)

These are done once. Skip on subsequent runs.

### 1. State Backend

```powershell
# S3 bucket + DynamoDB banao — state store karne ke liye
bash iac/bootstrap/setup-state-backend.sh
```

### 2. Docker Hub Secret in Secrets Manager

ECR pull-through cache ko Docker Hub credentials chahiye.
IaC ke bahar rakha — credentials kabhi state mein nahi honi chahiye.

```powershell
# Docker Hub pe jaao → Account Settings → Personal Access Tokens → Generate
# Phir secret banao (valid JSON format mandatory)

aws secretsmanager create-secret `
  --name "ecr-pullthroughcache/docker-hub" `
  --secret-string '{\"username\":\"<dockerhub-username>\",\"accessToken\":\"<dockerhub-token>\"}' `
  --profile sameer --region us-east-1

# Verify — isValid: true hona chahiye
aws ecr validate-pull-through-cache-rule `
  --ecr-repository-prefix docker-hub `
  --profile sameer --region us-east-1
```

> **Gotcha:** Secret must be valid JSON with quoted keys.
> `{username:foo,accessToken:bar}` = FAILS (no quotes around keys/values).
> `{"username":"foo","accessToken":"bar"}` = WORKS.
> PowerShell mein `\"` use karo ya `--secret-string` ko file se do.

### 3. Helm Repo Add

```powershell
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

---

## Create — Full Stack

### Step 1 — OpenTofu Init

```powershell
cd iac/envs/dev
$env:AWS_PROFILE = "sameer"
tofu init
```

### Step 2 — Plan (Review)

```powershell
# PowerShell mein --% stop-parsing token use karo
tofu --% plan -var-file=dev.tfvars
```

What will be created:
- VPC + subnets + route tables + 7 VPC endpoints
- EKS cluster (v1.33) + managed node group + 6 addons
- IAM roles (ebs-csi, s3-reader) + Pod Identity Associations
- ECR pull-through cache rule (docker-hub → registry-1.docker.io)
- ECR repos (docker-hub/amazon/aws-cli, docker-hub/library/nginx) + lifecycle policies
- S3 bucket + test objects

### Step 3 — Apply

```powershell
tofu --% apply -var-file=dev.tfvars
# "yes" type karo
# ~15-20 min lagenge
```

> **Gotcha:** Agar `/aws/eks/devops-lab-eks/cluster` log group already exists:
> ```powershell
> aws logs delete-log-group `
>   --log-group-name "/aws/eks/devops-lab-eks/cluster" `
>   --profile sameer --region us-east-1
> # PowerShell use karo — Git Bash /aws → path mangle karta hai
> ```

### Step 4 — kubectl Configure

```powershell
aws eks update-kubeconfig `
  --region us-east-1 `
  --name devops-lab-eks `
  --profile sameer

kubectl get nodes          # STATUS = Ready
kubectl get pods -A        # kube-system addons Running
```

### Step 5 — Gateway API CRDs

```powershell
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
```

> **Why v1.5.1:** Traefik v3.7.1 requires this version.
> v1.2.1 mein TLSRoute/BackendTLSPolicy CRDs nahi hain — Traefik errors.

### Step 6 — Traefik Deploy

```powershell
$ACCOUNT = "271169999916"
$REGION  = "us-east-1"

helm upgrade --install traefik traefik/traefik `
  -n traefik --create-namespace `
  -f app/traefik/values.yaml `
  --set "image.registry=${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com" `
  --wait --timeout=3m

kubectl get pods -n traefik    # Running
kubectl get svc -n traefik     # EXTERNAL-IP = NLB DNS
kubectl get gateway -n traefik # PROGRAMMED = True
```

> **Gotcha — image.registry vs image.repository:** Traefik chart has these as two
> separate fields. Setting only `image.repository` to the full ECR URL still
> prepends `docker.io/` → pull fails from private subnet.
> Always set both `image.registry` + `image.repository`.

> **Gotcha — NLB annotation:** `aws-load-balancer-type: external` + `nlb-target-type: ip`
> requires AWS Load Balancer Controller (separate install).
> Without LBC, use `aws-load-balancer-type: nlb` (in-tree controller).
> Already fixed in `app/traefik/values.yaml`.

> **Gotcha — Gateway `from: Same`:** Traefik creates its Gateway allowing only same-namespace
> routes by default. `gateway.listeners.web.namespacePolicy.from: All` in values.yaml fixes this
> so default namespace HTTPRoutes can attach.

### Step 7 — s3-lister Deploy

```powershell
$ACCOUNT = "271169999916"
$REGION  = "us-east-1"
$ECR     = "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

helm upgrade --install s3-lister app/s3-lister/chart `
  -n default `
  --set "image.init=${ECR}/docker-hub/amazon/aws-cli:latest" `
  --set "image.nginx=${ECR}/docker-hub/library/nginx:alpine" `
  --set "gateway.create=false" `
  --wait --timeout=3m

kubectl get pods           # s3-lister Running
kubectl get httproute      # ACCEPTED = True (default namespace)
```

> **Gotcha — gateway.create=false:** Traefik already created `traefik-gateway`.
> If s3-lister also creates it → Helm ownership conflict on upgrade.
> Pass `--set gateway.create=false` always.

### Step 8 — Test

```powershell
# NLB DNS lo
$NLB = kubectl get svc -n traefik traefik `
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

Write-Output "http://$NLB"
# Browser mein open karo
# Expected: S3 Buckets page — Pod Identity working, no hardcoded credentials
```

---

## Destroy — Clean Teardown

Order matters — Helm resources pehle hataao warna NLB dangling reh jaata hai.

### Step 1 — Apps Remove

```powershell
helm uninstall s3-lister -n default
helm uninstall traefik -n traefik
```

> **Why first:** Traefik uninstall = NLB delete. Agar tofu destroy pehle karo,
> NLB Service orphan rehta hai, AWS NLB dangling — manually cleanup karna padta.

### Step 2 — OpenTofu Destroy

```powershell
cd iac/envs/dev
$env:AWS_PROFILE = "sameer"
tofu --% destroy -var-file=dev.tfvars
# "yes" type karo
# ~10-15 min
```

### Step 3 — Verify (Optional)

```powershell
aws eks list-clusters --profile sameer --region us-east-1
# Output: {"clusters": []}  ← clean

aws ec2 describe-vpcs --profile sameer --region us-east-1 `
  --filters "Name=tag:project,Values=devops-lab" `
  --query 'Vpcs[].VpcId'
# Output: []  ← clean
```

---

## Quick Reference

| Command | When |
|---|---|
| `tofu init` | First time ya provider change ke baad |
| `tofu plan -var-file=dev.tfvars` | Har apply se pehle |
| `tofu apply -var-file=dev.tfvars` | Create/update infra |
| `aws eks update-kubeconfig ...` | Apply ke baad, har naye cluster pe |
| `kubectl apply -f gateway-api-crds.yaml` | Pehle ek baar (ya CRD version change pe) |
| `helm upgrade --install traefik ...` | Apply ke baad |
| `helm upgrade --install s3-lister ...` | Traefik ke baad |
| `helm uninstall` | Destroy se pehle |
| `tofu destroy -var-file=dev.tfvars` | Cleanup |
