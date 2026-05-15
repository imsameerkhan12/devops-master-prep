# Day 11 — IaC Lab Runbook

Complete create and destroy steps for the devops-lab environment.
Run all commands from the **repo root** unless noted otherwise.

---

## Prerequisites (One-Time Setup)

These are done once and survive cluster destroy + recreate.

### 1. Docker Hub Secret in Secrets Manager

ECR pull-through cache needs Docker Hub credentials.
Kept outside IaC — credentials must never be in state.

```powershell
aws secretsmanager create-secret `
  --name "ecr-pullthroughcache/docker-hub" `
  --secret-string '{\"username\":\"<dockerhub-username>\",\"accessToken\":\"<dockerhub-token>\"}' `
  --profile sameer --region us-east-1
```

> **Gotcha:** Must be valid JSON with quoted keys.
> `{username:foo}` = FAILS. `{"username":"foo"}` = WORKS.
> PowerShell mein `\"` use karo ya file se pass karo.

> **Note:** `infra-apply.yaml` workflow creates/updates this automatically before tofu apply.
> Manual step only needed for local runs.

---

## Create — Full Stack

### Step 1 — OpenTofu Init

```powershell
cd iac/envs/dev
tofu init
```

### Step 2 — Plan (Review)

```powershell
tofu --% plan -var-file=dev.tfvars -var="aws_profile=sameer"
```

What will be created:
- VPC + subnets + IGW + S3 gateway endpoint (free, no interface endpoints)
- EKS cluster v1.33 + 2× t3.medium nodes (public subnets, internet via IGW)
- 6 add-ons: vpc-cni (prefix delegation), kube-proxy, coredns, ebs-csi, pod-identity-agent, metrics-server
- ECR pull-through cache rule (docker-hub) + pre-created repos + lifecycle policies
- ECR repos for cert-manager images (quay-io/jetstack/*)
- IAM roles: ebs-csi, s3-reader, github-actions + Pod Identity associations
- GitHub Actions OIDC provider
- S3 app bucket + test objects

### Step 3 — Apply

```powershell
tofu --% apply -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"
# "yes" type karo
# ~17 min lagenge
```

### Step 4 — Configure kubectl

```powershell
aws eks update-kubeconfig `
  --region us-east-1 `
  --name devops-lab-eks `
  --profile sameer

kubectl get nodes          # STATUS = Ready
kubectl get pods -A        # kube-system pods Running
```

---

## Destroy — Clean Teardown

Order matters — Helm resources pehle hataao warna NLB dangling reh jaata hai.

### Step 1 — Helm Uninstall

```powershell
helm uninstall s3-lister    -n default      --ignore-not-found
helm uninstall cert-manager -n cert-manager --ignore-not-found
helm uninstall traefik      -n traefik      --ignore-not-found

# Wait for NLB to release
Start-Sleep 60
```

> Traefik uninstall = NLB delete. NLB ke ENIs ~60s mein release hote hain.
> Agar tofu destroy pehle karo aur NLB survive kare → VPC deletion fail.

### Step 2 — Verify NLBs Gone

```powershell
aws elbv2 describe-load-balancers --profile sameer --region us-east-1 `
  --query 'LoadBalancers[?Type==`network`].LoadBalancerArn'
# Should be empty []
```

If NLBs still exist, force-delete:
```powershell
aws elbv2 delete-load-balancer `
  --load-balancer-arn <arn> --profile sameer --region us-east-1
Start-Sleep 30
```

### Step 3 — OpenTofu Destroy

```powershell
cd iac/envs/dev
tofu --% destroy -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"
# "yes" type karo
# ~10-12 min
```

> **Gotcha — DependencyViolation on subnets:** VPC Interface Endpoints create ENIs
> in private subnets. Tofu destroy fails when these exist.
> Fix: delete endpoints manually before destroy:
> ```bash
> VPC_ID=$(aws ec2 describe-vpcs \
>   --filters "Name=tag:project,Values=devops-lab" \
>   --query 'Vpcs[0].VpcId' --output text)
>
> aws ec2 describe-vpc-endpoints \
>   --filters "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
>   --query 'VpcEndpoints[*].VpcEndpointId' --output text | \
>   xargs aws ec2 delete-vpc-endpoints --vpc-endpoint-ids
>
> # Wait ~2 min for ENIs to release, then retry tofu destroy
> ```
> Note: Interface endpoints removed from IaC — this only applies to old state.

### Step 4 — Verify Clean

```powershell
aws eks list-clusters --region us-east-1
# {"clusters": []}

aws ec2 describe-vpcs --profile sameer --region us-east-1 `
  --filters "Name=tag:project,Values=devops-lab" `
  --query 'Vpcs[].VpcId'
# []
```

### Step 5 — State Bucket Cleanup (only when fully done)

```bash
bash iac/bootstrap/teardown-state-backend.sh
# Prompts "yes" before deleting
# Deletes: S3 state bucket (all versions) + Docker Hub secret
```

> Only run when fully done with the environment — deletes tofu state.
> Without state, tofu loses track of resources. Run AFTER destroy completes.

---

## IaC Architecture

```
iac/
├── envs/dev/
│   ├── main.tf       # All resources: VPC module, EKS module, ECR, IAM, S3, OIDC
│   ├── variables.tf  # Input declarations
│   ├── dev.tfvars    # Dev values (region, cluster name, instance type)
│   ├── outputs.tf    # ECR registry, cluster name, role ARNs
│   └── versions.tf   # Provider versions + S3 backend config
└── modules/
    ├── vpc/          # VPC + subnets + S3 gateway endpoint
    └── eks/          # EKS cluster + managed node group + add-ons + Pod Identity
```

**Key design decisions:**
- Nodes in **public subnets** — direct internet via IGW, no NAT gateway cost
- **No interface VPC endpoints** — nodes reach ECR/STS/EKS via internet (public IPs), saves ~$87/month
- S3 **gateway** endpoint only — free, keeps S3 traffic off internet
- **Pod Identity** for all IAM (not IRSA) — simpler, no OIDC federation needed
- **Explicit IAM attachments** in dev/main.tf — survive node group recreations
- **-parallelism=20** — independent resources (ECR repos, IAM, S3) create simultaneously

---

## Quick Reference

| Command | When |
|---|---|
| `tofu init` | First time or provider change |
| `tofu plan --% -var-file=dev.tfvars -var="aws_profile=sameer"` | Before every apply |
| `tofu apply -parallelism=20 --% -var-file=dev.tfvars -var="aws_profile=sameer"` | Create/update infra |
| `aws eks update-kubeconfig ...` | After apply, on every new cluster |
| `helm uninstall traefik -n traefik` | Before destroy (releases NLB) |
| `tofu destroy -parallelism=20 --% -var-file=dev.tfvars -var="aws_profile=sameer"` | Cleanup |
| `bash iac/bootstrap/teardown-state-backend.sh` | Last step — state bucket + secret |
