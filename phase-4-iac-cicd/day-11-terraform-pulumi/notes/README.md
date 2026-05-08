# Day 11: OpenTofu + Pulumi Deep

> **Note:** We use OpenTofu — NOT Terraform.
> HashiCorp changed Terraform license to BSL 1.1 (August 2023) — no longer open source.
> OpenTofu = Linux Foundation fork, MPL 2.0, drop-in replacement. Same HCL, same state format.
> IBM acquired HashiCorp in 2024. Community moved to OpenTofu.

```bash
# Install
choco install opentofu

# Commands — same pattern, different binary
tofu init
tofu plan
tofu apply
tofu destroy
```

---

## State Management

### Why state exists
```
tofu apply karta hai → resources banata hai
State file = "kya ban gaya" ka record
Without state → OpenTofu nahi jaanta kya exist karta hai → sab recreate ho jaata
```

### Local state (never in production)
```
tofu.tfstate → sirf teri machine pe
Team = conflict, corruption
Git pe push → secrets plaintext mein leak
```

### Remote Backend — S3 (Modern — Terraform 1.10+ / OpenTofu 1.8+)

```hcl
terraform {
  backend "s3" {
    bucket       = "devops-lab-tfstate"
    key          = "eks/tofu.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true   # S3 native locking — DynamoDB nahi chahiye
  }
}
```

**DynamoDB wala purana tarika tha:**
```hcl
# OLD — avoid
backend "s3" {
  dynamodb_table = "terraform-lock"   # extra resource, extra cost, extra maintenance
}

# NEW — OpenTofu 1.8+ / Terraform 1.10+
backend "s3" {
  use_lockfile = true   # S3 conditional writes se locking — koi extra resource nahi
}
```

**Kya hota hai `use_lockfile = true` se:**
```
tofu apply start → S3 mein .tfstate.tflock file banata hai
Doosra apply try kare → lock file dekhe → fail with "state locked"
Apply complete → lock file delete
```

**Backend setup script:**
```bash
# Pehle S3 bucket banao (sirf ek baar)
aws s3api create-bucket \
  --bucket devops-lab-tfstate \
  --region us-east-1

# Versioning enable karo (rollback ke liye)
aws s3api put-bucket-versioning \
  --bucket devops-lab-tfstate \
  --versioning-configuration Status=Enabled

# Encryption enable karo
aws s3api put-bucket-encryption \
  --bucket devops-lab-tfstate \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

---

## Workspaces vs Separate State Files

| | Workspaces | Separate State Files |
|-|------------|---------------------|
| Structure | Same code, different state | Different dirs per env |
| Isolation | Weak (risk of mixing) | **Strong** |
| Recommendation | Dev/test only | **Production** |

**Best pattern:**
```
infra/
├── modules/          # reusable modules (vpc, eks, rds)
├── envs/
│   ├── dev/          # uses modules, dev tfvars, dev state bucket
│   ├── staging/
│   └── prod/         # separate state, separate AWS account ideally
```

---

## OpenTofu Modules

```hcl
module "vpc" {
  source = "git::https://github.com/org/tf-modules.git//vpc?ref=v1.2.0"

  cidr_block = "10.0.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]
}
```

**Best practices:**
- Always pin with `?ref=v1.2.0` — never `main` in prod
- Module structure: `main.tf`, `variables.tf`, `outputs.tf`
- Community modules: [registry.opentofu.org](https://registry.opentofu.org) — compatible with Terraform Registry modules

---

## Power User Commands

```bash
# Import existing resource (without recreating)
tofu import aws_instance.web i-1234abcd

# Rename resource in code without destroying
tofu state mv aws_instance.old aws_instance.new

# Remove from state but keep real resource
tofu state rm aws_instance.web

# Show state
tofu state list
tofu state show aws_instance.web

# Force recreate
tofu apply -replace=aws_instance.web

# Plan to file (use in CI/CD)
tofu plan -out=tfplan
tofu apply tfplan
```

---

## Drift Detection

```bash
# 1. tofu plan in CI/CD daily — any diff = drift alert
# 2. tofu plan -detailed-exitcode
#    exit 0 = no changes, exit 2 = changes exist

# 3. OpenTofu native (coming) — tofu test
# 4. Atlantis — PR-based, auto plan on PR
```

**Prevention:** SCPs / IAM policies blocking console changes to OpenTofu-managed resources.

---

## Pulumi

### Why Pulumi over OpenTofu?
- Real programming languages (TypeScript, Python, Go, C#)
- Full logic: loops, classes, conditionals
- Type safety + IDE autocomplete
- Unit tests for infra code

```bash
pulumi stack init production
pulumi config set aws:region us-east-1
pulumi config set --secret db_password supersecret

pulumi up       # preview + deploy
pulumi preview  # dry run
pulumi destroy  # tear down
```

### Pulumi Operator (resume item)
```yaml
apiVersion: pulumi.com/v1
kind: Stack
metadata:
  name: my-infra
spec:
  stack: org/project/production
  projectRepo: https://github.com/org/infra
  branch: main
```

---

## When to Use Each

| Situation | Tool |
|-----------|------|
| Team prefers declarative, large module ecosystem | OpenTofu |
| Complex infra logic (loops, conditionals, recursion) | Pulumi |
| Multi-cloud shared abstractions | Pulumi |
| IaC inside K8s GitOps style | Pulumi Operator |

---

## Interview — Key Points

> "We use OpenTofu — Terraform's BSL license change in 2023 made it non-open-source. OpenTofu is the Linux Foundation fork under MPL 2.0, drop-in replacement, same HCL."

> "State locking with S3 native `use_lockfile = true` — no DynamoDB table needed since OpenTofu 1.8. S3 conditional writes handle the lock."

---

## Hands-on Checklist
- [ ] OpenTofu install — `choco install opentofu`
- [ ] S3 backend setup — bucket + versioning + encryption
- [ ] Module: VPC + EKS + node group, reusable
- [ ] `tofu import` a manually-created resource
- [ ] Simulate drift: console change → `tofu plan` shows diff
- [ ] Pulumi TypeScript stack for same VPC
