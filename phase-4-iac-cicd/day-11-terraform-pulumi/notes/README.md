# Day 11: Terraform + Pulumi Deep

## Terraform State Management

### Remote Backend (Production Standard)
```hcl
terraform {
  backend "s3" {
    bucket         = "my-tfstate-prod"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"   # prevents concurrent apply
    encrypt        = true
  }
}
```

**Why locking:** Two engineers run `terraform apply` simultaneously → state corruption. DynamoDB lock prevents it.  
**NEVER commit:** `terraform.tfstate` contains secrets in plaintext.

---

## Workspaces vs Separate State Files

| | Workspaces | Separate State Files |
|-|------------|---------------------|
| Structure | Same code, different state | Different dirs/repos per env |
| Isolation | Weak (risk of mixing) | **Strong** |
| Code duplication | None | Some |
| Recommendation | Dev/test only | **Production** |

**Best pattern:**
```
infra/
├── modules/          # reusable modules (VPC, EKS, RDS)
├── envs/
│   ├── dev/          # uses modules, dev tfvars, dev state
│   ├── staging/
│   └── prod/         # separate state, separate AWS account ideally
```

---

## Terraform Modules

```hcl
module "vpc" {
  source = "git::https://github.com/org/tf-modules.git//vpc?ref=v1.2.0"

  cidr_block = "10.0.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}
```

**Best practices:**
- Always pin with `?ref=v1.2.0` (git tag) — never use `main` in prod
- Module structure: `main.tf`, `variables.tf`, `outputs.tf`
- Publish to Terraform Registry or internal module repo

---

## Power User Commands

```bash
# Import existing resource into state (without recreating)
terraform import aws_instance.web i-1234abcd

# Refactor: rename resource in code without destroying it
terraform state mv aws_instance.old aws_instance.new

# Remove from state but keep real resource alive
terraform state rm aws_instance.web

# Show what's in state
terraform state list
terraform state show aws_instance.web

# Force recreation on next apply
terraform apply -replace=aws_instance.web

# Plan output to file (use in CI/CD)
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Drift Detection

**What:** Manually changed infra (via console/CLI) ≠ Terraform state → drift

**Detection methods:**
```bash
# 1. terraform plan in CI/CD daily — any diff = drift alert
# 2. driftctl (open source):
driftctl scan --from tfstate+s3://bucket/state.tfstate

# 3. Atlantis (PR-based) — auto-plan on PR, shows drift
# 4. Spacelift / env0 — paid, enterprise
```

**Prevention:** SCP / IAM policies that block console changes to Terraform-managed resources.

---

## Pulumi Deep

### Why Pulumi Over Terraform?
- Real programming languages (TypeScript, Python, Go, C#)
- Full logic: loops, classes, conditionals, recursion
- Type safety + IDE autocomplete
- Unit tests for infra code
- Same language as your app code

### Stack = Environment
```bash
pulumi stack init production
pulumi config set aws:region us-east-1
pulumi config set --secret db_password supersecret

pulumi up       # preview + deploy
pulumi preview  # dry run
pulumi destroy  # tear down
```

### Pulumi Operator (YOUR RESUME ITEM)
- Runs Pulumi inside Kubernetes as a controller
- Watch a `Stack` CRD → run `pulumi up` automatically
- GitOps for infra: commit code → operator deploys

```yaml
apiVersion: pulumi.com/v1
kind: Stack
metadata:
  name: my-infra
spec:
  stack: org/project/production
  projectRepo: https://github.com/org/infra
  branch: main
  envRefs:
    AWS_REGION:
      type: Literal
      literal: us-east-1
```

---

## When to Use Each

| Situation | Tool |
|-----------|------|
| Team prefers declarative, large community modules | Terraform |
| Complex infra logic (conditional resources, loops) | Pulumi |
| Multi-cloud with shared abstractions | Pulumi |
| Simple CRUD infra, stable team | Terraform |
| IaC inside K8s (GitOps style) | Pulumi Operator |

---

## Hands-on Checklist
- [ ] Terraform module: VPC + EKS + node group, reusable
- [ ] Remote backend: S3 + DynamoDB, verify state is remote
- [ ] `terraform import` a manually-created resource
- [ ] Pulumi TypeScript stack for same VPC
- [ ] Simulate drift: console change → `terraform plan` shows diff
