# Day 11 Practice Notes — OpenTofu Deep Dive

---

## 1. WHY IaC? — Problem First

### Hindi

```
Bina IaC ke kya hota hai:

Day 1:
  Tu AWS Console pe jaata hai
  VPC banata hai → subnets → IGW → EKS → node group
  Sab manually clickety-click

Day 5:
  Kuch todna parta hai — phir se banao
  Yaad hai kya kya settings thi?
  Kaunsa security group? Kaunse ports?
  ...nahi pata → phir se 3 ghante

Team mein:
  Colleague staging pe kuch change karta hai console se
  Tu nahi jaanta — koi record nahi
  Production mein alag config hai — nobody knows why

AWS bill aata hai:
  Kaunsa resource tha? Kaun ne banaya? Kab?
  ...pata nahi
```

**IaC ka solution:**
```
Saari infrastructure = Code files mein
  ✅ Version controlled  — git history, blame, PR review
  ✅ Repeatable          — same code = same infra, har baar
  ✅ Destroyable         — ek command mein sab gone, bill zero
  ✅ Reviewable          — colleague PR review kar sakta hai
  ✅ Auditable           — kya tha, kab tha, kisne badla
```

### English — Interview Answer

> "Without IaC, infrastructure becomes a black box — nobody knows what was created, when, or why. IaC treats infrastructure like application code: version controlled, peer reviewed, repeatable. The same code deploys identical environments every time. We can spin up, tear down, and recreate entire environments in minutes instead of hours."

---

## 2. OpenTofu kya hai?

### Hindi

```
Terraform = HashiCorp ka tool
  2023: HashiCorp ne license BSL 1.1 kiya
  BSL = Business Source License = NOT open source
  Matlab: competitors use nahi kar sakte, certain use cases blocked

OpenTofu = Linux Foundation ka fork (August 2023)
  License: MPL 2.0 = truly open source
  Drop-in replacement: same HCL syntax, same state format
  IBM ne HashiCorp ko 2024 mein acquire kiya
  Community standard: OpenTofu
```

```
terraform init    →  tofu init
terraform plan    →  tofu plan
terraform apply   →  tofu apply
terraform destroy →  tofu destroy
.tf files         →  .tf files   (same syntax)
tfstate format    →  same format
```

### English — Interview Answer

> "HashiCorp changed Terraform's license to BSL 1.1 in August 2023, making it no longer open source. OpenTofu is the Linux Foundation fork under MPL 2.0 — a drop-in replacement with the same HCL syntax and state format. We use OpenTofu to stay on a truly open source toolchain. IBM acquired HashiCorp in 2024."

---

## 3. OpenTofu kaise kaam karta hai — Core Flow

### Hindi

```
Tu likhta hai → main.tf
  "mujhe ek S3 bucket chahiye, name = my-bucket"

tofu plan
  ↓
  OpenTofu padhta hai teri .tf files
  AWS se poochta hai "abhi kya hai?"
  Compare karta hai → diff dikhata hai
  "+ 1 resource add hoga: aws_s3_bucket.my-bucket"
  (actually kuch nahi banta — sirf preview)

tofu apply
  ↓
  Plan confirm karta hai
  AWS API calls karta hai → bucket banta hai
  State file update → "ye ban gaya"

tofu destroy
  ↓
  State file padhta hai → "kya kya tha"
  Sab delete karta hai
  State file empty
```

**3 files jo matter karti hain:**
```
main.tf      → DESIRED  — kya banana chahte ho
state file   → KNOWN    — kya ban gaya (OpenTofu ki notebook)
AWS actual   → REALITY  — AWS pe actual mein kya hai

Plan = diff between DESIRED vs KNOWN vs REALITY
  + = add karo
  - = delete karo
  ~ = modify karo
```

### English — Interview Answer

> "OpenTofu follows a desired-state model. You declare what you want in HCL, run `tofu plan` to preview the diff between desired and actual state, then `tofu apply` to make it real. The state file tracks what OpenTofu has created so it knows what to update or delete on subsequent runs."

---

## 4. State File — OpenTofu ki Notebook

### Hindi

```
State file kya hai:
  JSON file — OpenTofu ne jo banaya uska record
  Resource ID, ARNs, attributes — sab kuch

Bina state ke kya hota:
  Pehli apply → S3 bucket bana
  Doosri apply → state nahi pata → phir se banane ki koshish
  ERROR: bucket already exists 💀

State ke saath:
  Pehli apply → bucket bana → state mein likha
  Doosri apply → state dekha → "already hai" → No changes ✅

State file — 3 NEVER rules:
  ❌ Git pe push mat karo — secrets plaintext hote hain (DB passwords, keys)
  ❌ Manually edit mat karo — sirf tofu commands use karo
  ❌ Local state production mein mat use karo — team share nahi kar sakti
```

**Local vs Remote State:**
```
Local (learning ke liye only):
  tofu.tfstate → sirf teri machine pe
  Team use nahi kar sakti
  Machine crash → state lost → resources orphan ho gaye

Remote — S3 (production standard):
  tofu.tfstate → S3 bucket mein
  Team share kar sakti
  Versioning → rollback possible
  Locking → ek waqt mein ek apply
```

**S3 Locking — purana vs naya:**
```
Purana — AVOID:
  backend "s3" {
    dynamodb_table = "terraform-lock"  ← extra resource, extra cost
  }

Naya — 2024+ standard (OpenTofu 1.8+):
  backend "s3" {
    use_lockfile = true  ← bas itna, DynamoDB nahi chahiye
  }

Kaise kaam karta hai:
  tofu apply start → S3 mein .tfstate.tflock file banata hai (conditional write)
  Doosra apply try kare → lock file dekhe → "state locked"
  Apply complete → lock file delete
```

**S3 Backend — full config:**
```hcl
terraform {
  backend "s3" {
    bucket       = "devops-lab-tofu-state-271169999916"
    key          = "dev/terraform.tfstate"   # S3 path — env ke hisaab se alag rakho
    region       = "us-east-1"
    encrypt      = true                      # state file encrypt karo (secrets hain)
    use_lockfile = true                      # S3 native locking
  }
}
```

**State rollback — agar state corrupt ho:**
```bash
# 1. S3 versioning se purana state wapas lo
aws s3api list-object-versions --bucket my-state-bucket --prefix dev/terraform.tfstate

# 2. Current state backup lo
tofu state pull > state-backup.json

# 3. Import se wapas laao (last resort)
tofu import aws_eks_cluster.main devops-lab-eks
```

### English — Interview Answer

> "State file is OpenTofu's source of truth for what it has created. Without state, every apply would try to create everything from scratch. We always use remote state in S3 with `use_lockfile = true` for S3 native locking — no DynamoDB table needed since OpenTofu 1.8. State files must never be committed to Git since they contain plaintext secrets including database passwords and API keys."

---

## 5. Providers

### Hindi

```
Provider = plugin — OpenTofu ko batao kaunse cloud se baat karo
  AWS provider   → aws_* resources
  Azure provider → azurerm_* resources
  K8s provider   → kubernetes_* resources

AWS provider config:
  provider "aws" {
    region  = "us-east-1"
    profile = "sameer"      # AWS named profile
  }

Versions pin karna — mandatory:
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"    # 5.x chalega, 6.x nahi
    }
  }

~> = pessimistic constraint:
  ~> 5.0   = 5.0, 5.1, 5.99 ✅ | 6.0 ❌
  ~> 5.19  = 5.19, 5.20 ✅    | 6.0, 5.18 ❌
  = "5.19" = exactly 5.19 only

tofu init ke baad:
  .terraform/providers/ → provider binary download hota hai
  .terraform.lock.hcl   → exact version lock (git mein commit karo)
```

### English — Interview Answer

> "Providers are plugins that translate HCL into API calls for a specific cloud or service. Always pin provider versions with `~>` to allow patch updates but block major version breaks. The `.terraform.lock.hcl` file locks exact provider versions — commit this to Git so the whole team uses identical provider binaries."

---

## 6. Resources — Building Blocks

### Hindi

```
Resource = ek actual AWS cheez banao

Syntax:
  resource "<provider>_<type>" "<local_name>" {
    <arguments>
  }

Example:
  resource "aws_s3_bucket" "logs" {
    bucket = "my-logs-bucket-12345"
  }

  ├── aws        → provider
  ├── s3_bucket  → type (S3 bucket banao)
  ├── logs       → local name (code mein reference ke liye)
  └── bucket     → argument (actual bucket name AWS mein)
```

**Resources ek doosre ko reference karte hain:**
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id   # ← reference — VPC ka ID
  cidr_block = "10.0.1.0/24"
}

# OpenTofu dependency graph automatically banata hai:
# aws_vpc.main → pehle bano
# aws_subnet.private → baad mein (vpc_id chahiye)
```

**Lifecycle block:**
```hcl
resource "aws_rds_instance" "prod_db" {
  lifecycle {
    prevent_destroy       = true  # production DB accidentally delete na ho
    create_before_destroy = true  # naya banao pehle, phir purana delete (zero downtime)
    ignore_changes        = [tags] # tags manually change karo — drift ignore karo
  }
}
```

### English — Interview Answer

> "Resources are the fundamental building blocks — each represents one infrastructure object. OpenTofu builds a dependency graph from resource references, so it knows the correct creation order automatically. The `lifecycle` block gives fine-grained control — `prevent_destroy` for production databases, `create_before_destroy` for zero-downtime replacements."

---

## 7. Variables + Outputs

### Hindi

```
Variables = INPUT — flexible values
Outputs   = OUTPUT — bahar expose karo

Without variables:
  resource "aws_eks_cluster" "main" {
    name = "devops-lab-eks"    ← hardcoded — staging? prod?
  }

With variables:
  variable "cluster_name" {
    type        = string
    description = "EKS cluster name"
    default     = "devops-lab-eks"
  }

  resource "aws_eks_cluster" "main" {
    name = var.cluster_name    ← flexible
  }
```

**Variable types:**
```hcl
variable "name"    { type = string        }  # "devops-lab"
variable "count"   { type = number        }  # 3
variable "enabled" { type = bool          }  # true/false
variable "azs"     { type = list(string)  }  # ["us-east-1a", "us-east-1b"]
variable "tags"    { type = map(string)   }  # { env = "dev", project = "lab" }
```

**Values kaise dete hain (priority — upar wala jeet ta hai):**
```
1. -var flag:        tofu apply -var="cluster_name=prod-eks"
2. .tfvars file:     tofu apply -var-file=prod.tfvars
3. Environment var:  TF_VAR_cluster_name=prod-eks tofu apply
4. Default in code:  default = "devops-lab-eks"
```

**Outputs:**
```hcl
output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS API server URL — kubectl ke liye"
}

# tofu apply ke baad automatically print hota hai:
# Outputs:
#   cluster_endpoint = "https://ABC123.gr7.us-east-1.eks.amazonaws.com"

# Command se:
tofu output cluster_endpoint
tofu output -json   # CI/CD scripts ke liye
```

### English — Interview Answer

> "Variables parameterize configurations so the same modules work across environments — dev, staging, prod — just different tfvars files. Outputs expose values after apply. I use `tofu output -json` in CI/CD pipelines to capture cluster endpoints for `kubectl` configuration and subsequent deployment steps."

---

## 8. Data Sources

### Hindi

```
Resource    = banao (create karta hai — state mein track hota hai)
Data source = padhlo (sirf read, kuch nahi banata, state mein nahi)

Kab use karo:
  Kuch already exist karta hai — OpenTofu ne nahi banaya
  Us cheez ki ID/ARN chahiye

Example — current AWS account ID:
  data "aws_caller_identity" "current" {}

  "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/sameer"
  # Automatically fetch hota hai — hardcode nahi karna

Example — existing VPC (OpenTofu ne nahi banaya):
  data "aws_vpc" "existing" {
    filter {
      name   = "tag:Name"
      values = ["prod-vpc"]
    }
  }

  resource "aws_subnet" "new" {
    vpc_id = data.aws_vpc.existing.id   # existing VPC ki ID use karo
  }
```

### English — Interview Answer

> "Data sources read existing infrastructure without managing it. I use `aws_caller_identity` to dynamically fetch account IDs instead of hardcoding them — code works across accounts without changes. Data sources don't appear in state and don't get destroyed on `tofu destroy`."

---

## 9. Modules — Sabse Important Concept

### Hindi

```
Module = reusable code block
         Ek baar likho → multiple jagah use karo

Bina modules ke:
  dev/main.tf     → 500 lines (VPC + EKS + RDS + IAM)
  prod/main.tf    → 500 lines (same code copy-paste, thoda alag)
  staging/main.tf → 500 lines
  Total: 1500 lines duplicate

With modules:
  modules/vpc/    → 100 lines (ek baar likha)
  modules/eks/    → 100 lines

  dev/main.tf     → 30 lines (sirf module calls + dev values)
  prod/main.tf    → 30 lines (same modules + prod values)
  staging/main.tf → 30 lines

  Total: 290 lines — DRY ✅
```

**Module structure — standard:**
```
modules/
└── vpc/
    ├── main.tf       # resources
    ├── variables.tf  # inputs
    └── outputs.tf    # outputs (doosra module use karega)
```

**Module call karna:**
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"  # community module
  version = "~> 5.19"                        # always pin!

  name = "my-vpc"
  cidr = "10.0.0.0/16"
}

module "eks" {
  source = "../../modules/eks"   # local module

  vpc_id = module.vpc.vpc_id    # ← vpc module ka output → eks module ka input
                                 # module composition
}
```

**Community modules — don't reinvent:**
```
registry.opentofu.org → thousands of battle-tested modules

terraform-aws-modules/vpc/aws    → industry standard VPC
terraform-aws-modules/eks/aws    → industry standard EKS
terraform-aws-modules/iam/aws    → IRSA roles, IAM policies

Production pe yehi use hote hain — seedha likho mat
```

**Pin versions — NEVER `main`:**
```hcl
# ✅ Production
source = "git::github.com/org/modules.git//vpc?ref=v1.2.0"

# ❌ Kabhi bhi break ho sakta hai
source = "git::github.com/org/modules.git//vpc?ref=main"
```

### English — Interview Answer

> "Modules are the primary abstraction in OpenTofu — reusable units that encapsulate a set of resources. In production, I compose infrastructure from community modules like `terraform-aws-modules` for VPC and EKS — battle-tested and actively maintained. Environment directories just call these modules with different tfvars. I always pin module and provider versions for reproducibility."

---

## 10. tofu Commands — Daily Workflow

### Hindi

```bash
# SETUP — sirf pehli baar (ya module/provider add karne ke baad)
tofu init
  # providers download karta hai → .terraform/
  # modules download karta hai
  # S3 backend se connect karta hai

# PREVIEW — ALWAYS pehle dekho
tofu plan -var-file=dev.tfvars
  # kuch nahi banta — sirf diff dikhata hai
  # + add   - delete   ~ modify

# APPLY — actually banao
tofu apply -var-file=dev.tfvars
  # plan dikhata hai → "yes" type karo
  # ya -auto-approve CI/CD ke liye

# DESTROY — sab delete
tofu destroy -var-file=dev.tfvars

# STATE COMMANDS — power user
tofu state list                              # kya kya track ho raha hai
tofu state show aws_eks_cluster.main         # ek resource details
tofu state mv aws_instance.old aws_instance.new  # rename (delete nahi hoga)
tofu state rm aws_instance.web               # state se hatao (AWS pe rehega)
tofu import aws_s3_bucket.logs my-bucket     # existing resource ko manage karo

# PLAN TO FILE — CI/CD best practice
tofu plan -var-file=dev.tfvars -out=tfplan   # plan save karo
tofu apply tfplan                            # exact wahi apply karo (no surprises)

# DRIFT DETECTION
tofu plan -var-file=dev.tfvars -detailed-exitcode
# exit 0 = no changes
# exit 1 = error
# exit 2 = drift exists — CI/CD mein alert bhejo
```

### English — Interview Answer

> "My standard workflow: `tofu init` once, then always `tofu plan` before any `tofu apply` — review the diff carefully. In CI/CD, I use `tofu plan -out=tfplan` to save the exact plan, then `tofu apply tfplan` to apply precisely that — prevents drift between plan and apply in pipelines. I run `tofu plan -detailed-exitcode` daily in CI for drift detection — exit code 2 triggers a Slack alert."

---

## 11. File Structure — Best Practice

### Hindi

```
Ek environment = ek folder = ek state file

infra/
├── modules/                 # reusable — env-specific kuch nahi
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── eks/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── envs/
    ├── dev/                 # dev state → S3/dev/terraform.tfstate
    │   ├── versions.tf      # providers + backend
    │   ├── main.tf          # module calls
    │   ├── variables.tf     # variable declarations
    │   ├── outputs.tf       # outputs
    │   └── dev.tfvars       # dev values
    ├── staging/             # staging state → S3/staging/terraform.tfstate
    └── prod/                # prod state → separate AWS account ideally
```

**Workspaces vs Separate State Files:**
```
Workspaces (avoid for production):
  ek hi directory, different state
  tofu workspace new staging
  Risk: apply wrong workspace pe → prod destroy ho gaya

Separate directories (recommended):
  dev/ staging/ prod/ — physically alag
  Accidentally wrong env run nahi hoga
  Strong isolation ✅
```

### English — Interview Answer

> "I prefer separate directories per environment over workspaces — it's harder to accidentally apply to the wrong environment. Each directory has its own backend key pointing to a different S3 path. Modules stay in a shared `modules/` directory and are versioned independently."

---

## 12. Hamare Project mein OpenTofu

### Structure

```
iac/
├── bootstrap/
│   └── setup-state-backend.sh  # S3 bucket banao (run once)
├── modules/
│   ├── vpc/                    # VPC + subnets + 7 VPC endpoints
│   └── eks/                    # EKS + node group + addons + IRSA
└── envs/
    └── dev/
        ├── versions.tf         # providers + S3 backend
        ├── main.tf             # vpc + eks module calls
        ├── variables.tf        # inputs
        ├── outputs.tf          # cluster endpoint, OIDC ARN
        └── dev.tfvars          # dev values
```

### Workflow

```bash
# Step 1 — State backend (ek baar)
bash iac/bootstrap/setup-state-backend.sh

# Step 2 — Install
choco install opentofu -y
tofu --version  # >= 1.8

# Step 3 — Init
cd iac/envs/dev
tofu init

# Step 4 — Preview
tofu plan -var-file=dev.tfvars

# Step 5 — Apply (~20 min)
tofu apply -var-file=dev.tfvars

# Step 6 — kubectl configure
aws eks update-kubeconfig --profile sameer --region us-east-1 --name devops-lab-eks

# Step 7 — Verify
kubectl get nodes
kubectl get pods -n kube-system

# Step 8 — Destroy (jab kaam ho jaaye)
tofu destroy -var-file=dev.tfvars
```

### Concept to File Mapping

| Concept | File |
|---|---|
| State Backend | `envs/dev/versions.tf` → backend "s3" block |
| Providers | `envs/dev/versions.tf` → provider "aws" block |
| Variables | `envs/dev/variables.tf` + `dev.tfvars` |
| Outputs | `envs/dev/outputs.tf` |
| Data Sources | `envs/dev/main.tf` → data "aws_caller_identity" |
| Modules | `modules/vpc/` + `modules/eks/` |
| Module call | `envs/dev/main.tf` → module "vpc" + module "eks" |
| Resources | `modules/vpc/main.tf` → aws_vpc_endpoint, aws_security_group |
| Community modules | `terraform-aws-modules/vpc` + `terraform-aws-modules/eks` |

---

## Concept Summary

| Concept | Key Point |
|---|---|
| IaC | Infrastructure as Code — repeatable, auditable, destroyable |
| OpenTofu | Terraform fork — BSL license → OpenTofu MPL 2.0 (Linux Foundation) |
| State | OpenTofu ki notebook — kya ban gaya ka record |
| Remote State | S3 + use_lockfile=true — no DynamoDB needed (OpenTofu 1.8+) |
| Provider | Plugin — OpenTofu → AWS API. Always pin version |
| Resource | Ek AWS cheez banao. References se dependency graph banta hai |
| Variable | Input — hardcode mat karo. tfvars se values do |
| Output | Module se bahar expose karo. Doosre modules use karte hain |
| Data Source | Read-only — existing cheez ki info lo, kuch banata nahi |
| Module | Reusable block — ek baar likho, multiple envs mein use karo |
| Community Module | terraform-aws-modules — battle-tested, production standard |
| Drift | Console se manual change — tofu plan detect karta hai |
