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

Naya — 2024+ standard (OpenTofu 1.10+):
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

## 13. VPC Deep Dive — Private Subnets + 7 Endpoints

### Hindi

```
VPC = Virtual Private Cloud = tera private datacenter AWS mein

Soch aise:
  AWS = ek badi building (millions of servers)
  VPC = teri apni floor — sirf tere resources

VPC ke andar:
  Subnets     = rooms
  Route Table = corridor signs (traffic kahan jaaye)
  Security SG = room ke doors (kya andar, kya bahar)
  IGW         = building ka main gate (public internet)
```

**Public vs Private Subnet:**
```
Public Subnet:
  Route table: 0.0.0.0/0 → Internet Gateway
  Koi bhi resource internet pe ja sakta hai
  EKS nodes yahan nahi hone chahiye — exposed!

Private Subnet:
  Route table: sirf 10.0.0.0/16 → local
  Internet nahi — nodes safe hain
  Problem: images kaise pull karein bina internet ke?

Normal solution = NAT Gateway:
  Private subnet → NAT GW (public subnet) → Internet
  Cost: $32/month + data transfer

Hamaara solution = VPC Endpoints (cheaper + more secure):
  Private subnet → VPC Endpoint → AWS Service directly
  AWS ke andar hi rehta hai — internet nahi jaata
  S3 Gateway endpoint = FREE
```

**7 VPC Endpoints — kyu zaroori:**
```
Private EKS node ko ye AWS services chahiye:

1. s3 (Gateway, FREE)
   → ECR image layers S3 mein stored hain
   → Nodes yahan se images pull karte hain

2. ec2 (Interface)
   → nodeadm bootstrap — node EKS se connect karta hai
   → VPC CNI — ENI banata hai nodes pe (pod networking)

3. ecr.api (Interface)
   → Image metadata — "kaunsa digest hai is image ka?"

4. ecr.dkr (Interface)
   → Actual image pull (docker pull equivalent)

5. eks (Interface)
   → K8s API server — kubectl commands yahan jaati hain

6. sts (Interface)
   → Token exchange — AWS credentials ke liye

7. eks-auth (Interface)
   → Pod Identity Agent → AWS STS se temp creds fetch karta hai
```

**for_each pattern — hamare code mein:**
```hcl
# iac/modules/vpc/main.tf
locals {
  interface_endpoints = {
    ec2      = "ec2"
    ecr_api  = "ecr.api"
    ecr_dkr  = "ecr.dkr"
    eks      = "eks"
    sts      = "sts"
    eks_auth = "eks-auth"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints
  # each.key   = ec2, ecr_api, ecr_dkr ...
  # each.value = "ec2", "ecr.api", "ecr.dkr" ...
  service_name = "com.amazonaws.us-east-1.${each.value}"
}
# 6 resources, ek block — DRY ✅
```

### English — Interview Answer

> "We use VPC endpoints instead of NAT Gateway — cheaper and more secure since traffic stays within AWS network. For private EKS, 7 endpoints are mandatory: S3 gateway (free, ECR image layers), EC2 (node bootstrap + CNI ENI management), ECR API + ECR DKR (image pull), EKS (K8s API), STS (credential exchange), EKS-auth (Pod Identity Agent). We use `for_each` over a local map to create all 6 interface endpoints from a single resource block — no duplication."

---

## 14. EKS Deep Dive — Control Plane, Node Groups, Addons

### Hindi

```
EKS = Elastic Kubernetes Service
    = AWS-managed Kubernetes control plane

Control Plane (AWS manage karta hai, tujhe nahi dikhta):
  API Server     → kubectl commands yahan aati hain
  etcd           → cluster ka database (desired state)
  Scheduler      → pod ko node pe assign karta hai
  Controller Mgr → desired state maintain karta hai

Data Plane (tera — EC2 nodes):
  kubelet          → har node pe — API server se orders leta hai
  kube-proxy       → Service traffic routing
  container runtime → containers chalata hai (containerd)
```

**Managed Node Group:**
```
Kya AWS karta hai automatically:
  ✅ Node replace (crash hone pe)
  ✅ Rolling update (K8s version upgrade pe)
  ✅ Scaling (min/max ke beech, ASG se)
  ✅ AMI updates

Tu nahi karta:
  ❌ SSH into nodes
  ❌ Manual terminate + replace
  ❌ kubelet config
```

**EKS Addons — har ek kya karta hai:**
```
vpc-cni:
  Pod networking — pods ko real VPC IP milti hai
  ENI (Elastic Network Interface) banata hai nodes pe
  Har pod = real VPC IP (AWS-native approach)

kube-proxy:
  Service → Pod traffic forward karna
  iptables/ipvs rules manage karta hai

coredns:
  DNS server cluster ke andar
  "my-service.default.svc.cluster.local" → pod IP resolve

aws-ebs-csi-driver:
  PersistentVolume = EBS volume
  Pod start → EBS attach, Pod stop → EBS detach
  Pod dusre node pe gaya → EBS reattach

eks-pod-identity-agent:
  DaemonSet — har node pe chalta hai
  Pod startup pe intercept karta hai
  AWS STS se temp credentials fetch + inject karta hai

metrics-server:
  Resource usage collect karta hai
  kubectl top nodes / kubectl top pods ke liye
  HPA (Horizontal Pod Autoscaler) isko use karta hai
```

**EKS Access Entry — aws-auth replace:**
```
Purana tarika (avoid):
  aws-auth ConfigMap — manually edit YAML
  Galti hone pe cluster lock out
  No audit trail — koi IaC nahi

Naya tarika (EKS 1.23+):
  aws_eks_access_entry           → IAM principal register karo
  aws_eks_access_policy_association → policy attach karo

Hamare code mein (iac/modules/eks/main.tf):
  admin_iam_user_arn = arn:aws:iam::<account>:user/sameer
  Policy = AmazonEKSClusterAdminPolicy
  Scope = cluster (poora cluster admin)
```

### English — Interview Answer

> "EKS manages the control plane — API server, etcd, scheduler. We manage the data plane via Managed Node Groups, which handle node replacement, rolling upgrades, and scaling automatically. Each addon serves a specific purpose: VPC CNI assigns real VPC IPs to pods using ENIs, EBS CSI handles persistent volumes, Pod Identity Agent injects AWS credentials. We use Access Entries instead of the legacy aws-auth ConfigMap — it's IaC-manageable, auditable via CloudTrail, and can't accidentally lock you out."

---

## 15. Pod Identity — IAM for Pods (No Hardcoding)

### Hindi

```
Problem: Pod ko S3 read karna hai
         AWS credentials kahan se aayein?

❌ Bad — Hardcode karo:
   env:
     AWS_ACCESS_KEY_ID: AKIA...
   Problem: key rotate → deployment update
            leak → full account compromise

❌ Old — IRSA (IAM Roles for Service Accounts):
   OIDC Provider banao (cluster-specific URL)
   Service Account annotate karo
   Trust policy mein OIDC URL daalo
   Pod JWT → AWS STS → temp creds
   Problem: cluster recreate → OIDC URL change → trust policy update
            cluster-specific = not portable

✅ New — Pod Identity (2023 standard):
   Trust policy: pods.eks.amazonaws.com (static, cluster-agnostic)
   No OIDC URL, no SA annotation
   Same IAM role = any EKS cluster use kar sakta hai
```

**Pod Identity flow — step by step:**
```
1. Pod start hota hai (s3-reader-sa ServiceAccount se)

2. Pod Identity Agent (DaemonSet, har node pe) dekhta hai:
   "Is pod ka SA EKS Association mein hai?"

3. Association table:
   cluster=devops-lab, ns=default, sa=s3-reader-sa → role=s3-reader-role

4. Agent STS se baat karta hai (eks-auth VPC endpoint):
   "Is pod ke liye temp credentials do"

5. Pod ko credentials milti hain via projected volume:
   /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/token

6. AWS SDK automatically pick up karta hai — no config needed

Flow:
  Pod → Pod Identity Agent → eks-auth endpoint → AWS STS → temp creds
```

**Hamare code mein — 3 pieces (iac/envs/dev/main.tf):**
```hcl
# 1. IAM Role — trust = pods.eks.amazonaws.com
resource "aws_iam_role" "s3_reader" {
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# 2. Policy attach
resource "aws_iam_role_policy_attachment" "s3_reader" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# 3. Association — IAM Role ↔ K8s ServiceAccount link
resource "aws_eks_pod_identity_association" "s3_reader" {
  cluster_name    = module.eks.cluster_name
  namespace       = "default"
  service_account = "s3-reader-sa"   # app/s3-lister/serviceaccount.yaml
  role_arn        = aws_iam_role.s3_reader.arn
}
```

**IRSA vs Pod Identity — interview table:**
```
                    IRSA                  Pod Identity
Trust policy        OIDC URL (cluster)    pods.eks.amazonaws.com
Cluster-specific    Yes                   No (portable)
SA annotation       Required              Not required
Cross-account       Complex               Simpler
Agent needed        No (JWT flow)         Yes (eks-pod-identity-agent addon)
2023+ standard      No                    YES ✅
```

### English — Interview Answer

> "Pod Identity is the 2023 replacement for IRSA. Instead of OIDC federation with cluster-specific URLs in trust policies, Pod Identity uses a static service principal `pods.eks.amazonaws.com` — the same IAM role works on any EKS cluster. The Pod Identity Agent DaemonSet intercepts pod startup, checks the EKS Association table (namespace + ServiceAccount → IAM Role), calls AWS STS via the eks-auth VPC endpoint, and injects temporary credentials via projected volume. The AWS SDK picks these up automatically — no hardcoded credentials, no ServiceAccount annotations."

---

## 16. Traefik + Gateway API — Modern Ingress

### Hindi

```
Problem: Pod ke bahar traffic kaise laao?

Old way — Ingress:
  kind: Ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
  
  Problem:
    Har controller ka alag annotation set
    NGINX annotations = AWS pe nahi chalega
    ALB annotations = Azure pe nahi chalega
    Cloud-specific garbage — not portable

New way — Gateway API (Kubernetes SIG project, 2023+ standard):
  3 resources, clearly separated roles
  Portable across all implementations
  Formal versioning
```

**Gateway API — 3 resources, 3 roles:**
```
GatewayClass (cluster-wide, cluster admin banata hai):
  "Traefik implementation available hai"
  kind: GatewayClass
  spec:
    controllerName: traefik.io/gateway-controller

Gateway (namespace: traefik, network team banati hai):
  "Port 80 pe sun, sabhi namespaces se routes allow"
  kind: Gateway
  spec:
    gatewayClassName: traefik
    listeners:
      - port: 80
        allowedRoutes:
          namespaces:
            from: All

HTTPRoute (namespace: default, app developer banata hai):
  "/ → s3-lister service pe bhejo"
  kind: HTTPRoute
  spec:
    parentRefs:
      - name: traefik-gateway
        namespace: traefik
    rules:
      - matches:
          - path: { type: PathPrefix, value: / }
        backendRefs:
          - name: s3-lister
            port: 80
```

**Separation of concerns:**
```
Cluster admin  → GatewayClass (kaunsa implementation)
Network team   → Gateway (ports, listeners, security)
App developer  → HTTPRoute (routing rules only)

Ingress mein = sab mix — cluster admin config + app routing ek jagah
Gateway API  = clear boundaries ✅
```

**Traffic flow — hamare project mein:**
```
Internet
  → NLB (AWS Network Load Balancer)
     → Traefik pod (namespace: traefik)
        → Gateway (port 80 listener)
           → HTTPRoute match: prefix /
              → s3-lister Service (ClusterIP)
                 → s3-lister Pod (nginx container)
```

**Traefik kyu — NGINX nahi:**
```
NGINX Ingress:
  2015 se hai — Ingress API based
  Gateway API = afterthought, incomplete
  Annotation-heavy config

Traefik:
  Gateway API = first-class citizen
  Helm install = 5 minutes
  Dashboard built-in (debugging easy)
  Automatic HTTPS support
  Hamare case mein: NLB + Gateway API = perfect fit
```

### English — Interview Answer

> "Gateway API is the official Kubernetes SIG replacement for Ingress — standardized, portable, with proper role separation. GatewayClass is managed by cluster admins (which implementation — Traefik, Istio, Envoy), Gateway by network teams (ports, security, listeners), and HTTPRoute by app developers (routing rules). Unlike Ingress with its cloud-specific annotations, HTTPRoute is completely portable. Traffic flows: NLB → Traefik pod → Gateway listener → HTTPRoute match → ClusterIP Service → Pod. We use Traefik for its first-class Gateway API support and simple Helm install."

---

## 17. NGINX Ingress vs Traefik

### Hindi

```
Dono kya karte hain:
  Bahar se traffic → cluster ke andar route karo
  External load balancer ka kaam

NGINX Ingress Controller:
  2015 se — sabse purana, sabse popular
  NGINX (web server) ko reverse proxy ki tarah use karta hai
  Config change hone pe → nginx.conf regenerate → NGINX reload
  → Brief downtime possible har config update pe

Traefik:
  2016 se — cloud-native soch ke banaya (Go mein)
  Kubernetes API watch karta hai — auto-discovery
  Config change → hot reload — zero downtime ✅
```

**Head to head:**
```
Feature              NGINX Ingress        Traefik
─────────────────────────────────────────────────
Config reload        Full NGINX reload    Hot reload (zero downtime) ✅
Gateway API support  Partial (retrofit)   First-class ✅
Dashboard            No                   Yes (built-in) ✅
Let's Encrypt        Manual setup         Automatic ✅
Annotations needed   Many (complex)       Fewer
Performance          Very high            High (comparable)
Community            Huge                 Large
```

**Annotations problem:**
```yaml
# NGINX Ingress — annotation hell (cloud-specific, not portable)
annotations:
  kubernetes.io/ingress.class: "nginx"
  nginx.ingress.kubernetes.io/rewrite-target: /$1
  nginx.ingress.kubernetes.io/proxy-body-size: "50m"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "600"

# Traefik — Gateway API (clean, portable, no annotations)
kind: HTTPRoute
spec:
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: my-service
          port: 80
```

**Kab kya choose karein:**
```
NGINX choose karo:
  → Legacy project already NGINX pe
  → Maximum community resources chahiye
  → Fine-grained NGINX tuning chahiye

Traefik choose karo (new projects):
  → Gateway API adopt karna hai ✅
  → Dashboard + observability chahiye ✅
  → Automatic HTTPS chahiye ✅
  → Hot reload = zero downtime chahiye ✅
```

### English — Interview Answer

> "Both route external traffic into the cluster but differ in philosophy. NGINX Ingress wraps the NGINX web server — config changes trigger a full NGINX reload causing brief disruptions. Traefik is cloud-native — it watches the Kubernetes API and hot-reloads with zero downtime. The key differentiator today is Gateway API: Traefik treats it first-class while NGINX retrofitted support. For new projects, Traefik wins — cleaner config, built-in dashboard, automatic Let's Encrypt, no annotation sprawl."

---

## 18. Traefik Dashboard — Access kaise karein

### Hindi

```
Traefik dashboard kya dikhata hai:
  Routers    → kaunse routes active hain (HTTPRoute)
  Services   → backend services (health, load balancing)
  Middlewares → transformations (auth, rate limit, headers)
  Providers  → kahan se config aa rahi hai (Kubernetes, Docker)

Dashboard port: 8080 (internal, expose nahi hota by default)
API port: 8080/api/
```

**3 ways to access:**

**Method 1 — Port Forward (dev/debug, easiest):**
```bash
# Traefik pod ka naam dhundho
kubectl get pods -n traefik

# Port forward karo laptop pe
kubectl port-forward -n traefik pod/traefik-<hash> 8080:8080

# Browser mein:
# http://localhost:8080/dashboard/
# (trailing slash zaroori hai)
```

**Method 2 — HTTPRoute se expose (staging mein, auth ke saath):**
```yaml
# NEVER expose dashboard without auth — security risk
# BasicAuth middleware pehle:
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: dashboard-auth
  namespace: traefik
spec:
  basicAuth:
    secret: traefik-dashboard-auth   # kubectl create secret generic

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
  hostnames:
    - "traefik.yourdomain.com"      # domain chahiye
  rules:
    - backendRefs:
        - name: traefik
          port: 8080
```

**Method 3 — Helm values se enable (hamare values.yaml mein):**
```yaml
# app/traefik/values.yaml mein add karo:
ingressRoute:
  dashboard:
    enabled: true       # Traefik ka built-in IngressRoute banata hai
    # BUT: production mein auth add karo!
```

**Port forward command — hamare project mein:**
```bash
# Cluster up hone ke baad:
kubectl port-forward -n traefik \
  $(kubectl get pods -n traefik -o name | head -1) \
  8080:8080

# Then open: http://localhost:8080/dashboard/
```

**Dashboard mein kya dekhoge:**
```
Routers section:
  s3-lister@kubernetescrd → backend: s3-lister:80 → Status: Enabled ✅

Services section:
  s3-lister-default-80 → 1 server → 10.0.x.x:80 (pod IP)

Providers:
  kubernetes (watching K8s API)
  kubernetescrd (watching Gateway API CRDs)
```

### English — Interview Answer

> "Traefik's dashboard runs on port 8080 and shows active routers, backend services, and middlewares in real-time. For development, `kubectl port-forward` is the quickest access — forward pod port 8080 to localhost, then hit `http://localhost:8080/dashboard/`. For staging environments, expose it via HTTPRoute with BasicAuth middleware — never expose the dashboard without authentication since it reveals full routing config. In production, we typically disable it or restrict to VPN-only access."

---

## 19. Helm Chart — Raw Manifests se Conversion

### Hindi

```
Raw manifests kya problem dete hain:
  deployment.yaml mein hardcoded values:
    replicas: 1        ← dev mein theek, prod mein 3 chahiye
    region: us-east-1  ← eu-west-1 chahiye European cluster ke liye
    image: nginx:alpine ← staging pe naya image test karna hai

  Dev ke liye alag file, prod ke liye alag file
  → Copy-paste → drift → bugs

Helm kya karta hai:
  Templates + Values = Final YAML
  Ek template, alag values file dev/prod ke liye
```

**Helm Chart Structure:**
```
chart/
├── Chart.yaml          ← chart ka naam, version, description
├── values.yaml         ← default values (override ho sakti hain)
└── templates/
    ├── _helpers.tpl    ← reusable snippets (labels etc.)
    ├── serviceaccount.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── httproute.yaml
```

**Chart.yaml — 2 versions:**
```yaml
apiVersion: v2
name: s3-lister
version: 0.1.0        # CHART version — chart code change pe badhao
appVersion: "1.0.0"   # APP version — actual app ka version
```

**Template syntax — key concepts:**
```yaml
# .Values.xxx → values.yaml se value lo
replicas: {{ .Values.replicaCount }}

# .Release.Name → helm install ke waqt diya hua naam
name: {{ .Release.Name }}

# .Release.Namespace → -n flag se
namespace: {{ .Release.Namespace }}

# .Chart.Name, .Chart.Version → Chart.yaml se
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}

# | quote → string mein wrap karo ("us-east-1")
value: {{ .Values.aws.region | quote }}

# toYaml + nindent → nested YAML block paste karo (indented)
resources:
  {{- toYaml .Values.resources | nindent 12 }}

# include → _helpers.tpl se snippet insert karo
labels:
  {{- include "s3-lister.labels" . | nindent 4 }}

# if/end — conditional block
{{- if .Values.gateway.create }}
  # sirf tabhi render hoga jab gateway.create: true ho
{{- end }}
```

**_helpers.tpl — kyu zaroori hai:**
```
Labels har resource pe same chahiye (Deployment, Service, SA)
Ek jagah define karo → sab jagah include karo
Change ek jagah → sab jagah update

{{- define "s3-lister.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

# Use karo:
labels:
  {{- include "s3-lister.labels" . | nindent 4 }}
```

**Helm commands:**
```bash
# Install (pehli baar)
helm install s3-lister ./app/s3-lister/chart -n default

# Upgrade (update karo)
helm upgrade s3-lister ./app/s3-lister/chart -n default

# Install ya upgrade — idempotent (CI/CD ke liye)
helm upgrade --install s3-lister ./app/s3-lister/chart -n default

# Values override karo
helm upgrade --install s3-lister ./app/s3-lister/chart \
  --set replicaCount=3 \
  --set aws.region=eu-west-1

# Alag values file (prod ke liye)
helm upgrade --install s3-lister ./app/s3-lister/chart \
  -f values-prod.yaml

# Template render dekho (kuch deploy nahi hota — dry run)
helm template s3-lister ./app/s3-lister/chart

# Release list
helm list -n default

# Rollback
helm rollback s3-lister 1   # revision 1 pe wapas

# Uninstall
helm uninstall s3-lister -n default
```

**gateway.create flag — kyu:**
```yaml
# values.yaml
gateway:
  create: true    # pehli install pe Gateway banta hai

# Agar Gateway already exist karta hai (traefik Helm chart se):
helm upgrade --install s3-lister ./app/s3-lister/chart \
  --set gateway.create=false
# Gateway skip, sirf HTTPRoute banao
```

### English — Interview Answer

> "We converted raw manifests to a Helm chart to enable environment-specific deployments without code duplication. The chart has `values.yaml` with defaults — dev uses them as-is, prod overrides `replicaCount`, region, and image tag via a separate `values-prod.yaml`. Template functions like `toYaml | nindent` handle nested blocks cleanly, and `_helpers.tpl` centralizes label definitions so all resources stay consistent. In CI/CD, we use `helm upgrade --install` — idempotent, works for both first deploy and updates."

---

## 20. Hands-On Walkthrough — Full Deploy + Destroy

### Step 1 — OpenTofu Install (Windows)

```powershell
# Admin PowerShell mein run karo (choco admin chahiye)
$version = "1.9.1"
$url = "https://github.com/opentofu/opentofu/releases/download/v$version/tofu_${version}_windows_amd64.zip"
$installDir = "C:\Program Files\OpenTofu"

New-Item -ItemType Directory -Force -Path $installDir
Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\opentofu.zip"
Expand-Archive -Path "$env:TEMP\opentofu.zip" -DestinationPath $installDir -Force

# System PATH mein add karo — permanent, saari shells mein milega
[Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";$installDir", "Machine")

# Verify
tofu --version   # OpenTofu v1.9.1
```

> **Actual output:** `OpenTofu v1.9.1 on windows_amd64`

**Gotcha — use_lockfile version:**
```
# versions.tf mein use_lockfile = true likha tha
# Error: "An argument named use_lockfile is not expected here"
# Reason: use_lockfile needs OpenTofu 1.10+ — we are on 1.9.1
# Fix: comment out karo for dev (no locking OK for solo work)

# use_lockfile = true  # OpenTofu 1.10+ needed
```

**Gotcha — PowerShell flag parsing:**
```powershell
# tofu plan -var-file=dev.tfvars → Error: "Too many command line arguments"
# Reason: PowerShell -var-file ko apna parameter samajhta hai

# Fix: stop-parsing token --% use karo
tofu --% -var-file=dev.tfvars
# --% ke baad PowerShell kuch parse nahi karta — raw pass karta hai tofu ko
```

### Step 2 — State Backend (ek baar run karo)

```bash
bash iac/bootstrap/setup-state-backend.sh
```

> **Actual output:**
> ```
> === OpenTofu State Backend Setup ===
> Bucket: s3://devops-lab-tofu-state-271169999916
> { "Location": "/devops-lab-tofu-state-271169999916" }
> === Done ===
> ```

```
Script kya karta hai:
  aws s3api create-bucket        → bucket banao
  put-bucket-versioning          → state rollback possible
  put-bucket-encryption (AES256) → state file mein secrets hain
  put-public-access-block        → kabhi public nahi hona chahiye
```

### Step 3 — tofu init

```powershell
# AWS_PROFILE set karo — backend init pe chahiye
# (provider config pehle nahi padhta, backend pehle connect hota hai)
$env:AWS_PROFILE = "sameer"
cd iac/envs/dev
tofu init
```

> **Actual output:**
> ```
> Successfully configured the backend "s3"!
> Installing hashicorp/aws v5.100.0...
> Installing hashicorp/tls v4.3.0...
> Installing hashicorp/time v0.14.0...
> OpenTofu has been successfully initialized!
> ```

```
Kya download hua:
  .terraform/providers/ → AWS, TLS, Time, CloudInit, Null provider binaries
  .terraform/modules/   → terraform-aws-modules/vpc v5.21.0
                          terraform-aws-modules/eks v20.37.2
  .terraform.lock.hcl   → exact versions locked (git mein commit karo)
```

**Gotcha — AWS_PROFILE backend ke liye:**
```
tofu init karte waqt backend S3 connect karta hai
Backend config mein profile nahi hota (provider config mein hota hai)
Provider config baad mein padhta hai
So: AWS_PROFILE env var set karna padta hai init se pehle

Fix: $env:AWS_PROFILE = "sameer" (ya har command se pehle set karo)
```

### Step 4 — tofu plan (review before apply)

```powershell
$env:AWS_PROFILE = "sameer"
tofu --% plan -var-file=dev.tfvars
```

> **Actual output (summary):**
> ```
> Plan: 83 to add, 0 to change, 0 to destroy
>
> Changes to Outputs:
>   + cluster_endpoint       = (known after apply)
>   + cluster_name           = "devops-lab-eks"
>   + kubectl_config_command = "aws eks update-kubeconfig ..."
>   + s3_bucket_name         = (known after apply)
>   + s3_reader_role_arn     = (known after apply)
>   + vpc_id                 = (known after apply)
> ```

```
83 resources mein kya kya hai:
  VPC + 2 private subnets + 2 public subnets + route tables
  1 S3 Gateway endpoint + 6 Interface endpoints
  Security Group for endpoints
  EKS cluster + managed node group
  6 addons (vpc-cni, kube-proxy, coredns, ebs-csi, pod-identity-agent, metrics-server)
  IAM roles: s3-reader + ebs-csi
  Pod Identity Associations: s3-reader-sa + ebs-csi-controller-sa
  EKS Access Entry + Policy Association (sameer = cluster admin)
  S3 bucket + 2 test objects (hello.txt, pod-identity-test.txt)

Plan padhna:
  + = naya banega
  ~ = modify hoga
  - = delete hoga
  (known after apply) = apply ke baad pata chalega (ARN, ID etc.)
```

### Step 5 — tofu apply (~20 min)

```powershell
$env:AWS_PROFILE = "sameer"
tofu --% apply -var-file=dev.tfvars -auto-approve

# Order jisme banta hai (dependency graph se):
#   VPC → subnets → route tables → VPC endpoints
#   EKS control plane → node group → addons
#   IAM roles → Pod Identity Associations
#   S3 bucket → test objects
```

**Gotcha — Orphaned resources from previous runs:**
```
Error: ResourceAlreadyExistsException:
  The specified log group already exists
  Log group: /aws/eks/devops-lab-eks/cluster

Reason: Day 5 mein eksctl se cluster banaya tha
        destroy.sh ne CloudWatch log group delete nahi kiya
        OpenTofu banane ki koshish karta hai → already exists → fail

Fix: Manually delete karo, phir apply
  aws logs delete-log-group \
    --log-group-name "/aws/eks/devops-lab-eks/cluster" \
    --profile sameer --region us-east-1

Lesson: Pehle existing resources check karo:
  aws eks list-clusters --profile sameer --region us-east-1
  aws logs describe-log-groups --profile sameer (filter /aws/eks/)

Bonus Gotcha — Git Bash path mangling:
  aws logs delete-log-group --log-group-name /aws/eks/...
  Git Bash converts /aws → C:/Program Files/Git/aws → FAIL
  Fix: PowerShell use karo, ya MSYS_NO_PATHCONV=1 set karo
```

**Gotcha — AWS Security Group description ASCII only:**
```
Error: creating Security Group: InvalidParameterValue:
  Value (VPC endpoints — allow HTTPS from VPC CIDR) for parameter
  GroupDescription is invalid. Character sets beyond ASCII not supported.

Reason: Em dash — (U+2014) is non-ASCII
Fix: Replace — with regular hyphen -
  "VPC endpoints - allow HTTPS from VPC CIDR"

Rule: AWS resource names/descriptions = ASCII only
      Comments mein use karo, AWS strings mein nahi
```

### Step 6 — kubectl configure

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name devops-lab-eks \
  --profile sameer

kubectl get nodes   # nodes Ready hone chahiye
kubectl get pods -n kube-system   # addons running hone chahiye
```

### Step 7 — Gateway API CRDs

```bash
# Traefik v3.7.1 needs v1.5.1 — v1.2.1 mein TLSRoute/BackendTLSPolicy missing
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml
```

### Step 8 — Traefik install (Helm)

```bash
# image.registry alag set karo — chart registry+repository separately prepend karta hai
# gateway.create=false via values.yaml (Traefik apna Gateway banata hai from=All ke saath)
helm upgrade --install traefik traefik/traefik \
  -n traefik --create-namespace \
  -f app/traefik/values.yaml \
  --set "image.registry=<account-id>.dkr.ecr.<region>.amazonaws.com" \
  --wait

kubectl get pods -n traefik      # Running
kubectl get gateway -n traefik   # PROGRAMMED = True
```

### Step 9 — s3-lister app deploy (Helm)

```bash
ECR="<account-id>.dkr.ecr.<region>.amazonaws.com"

helm upgrade --install s3-lister ./app/s3-lister/chart \
  -n default \
  --set "image.init=${ECR}/docker-hub/amazon/aws-cli:latest" \
  --set "image.nginx=${ECR}/docker-hub/library/nginx:alpine" \
  --set "gateway.create=false" \
  --wait

kubectl get pods          # Running
kubectl get httproute     # Accepted = True
```

### Step 10 — Test in browser

```bash
kubectl get svc -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# http://<NLB-DNS>/ → S3 Buckets listed, Pod Identity working
```

### Step 11 — Destroy (jab kaam ho jaaye)

```bash
# Order matters — Helm pehle, tofu baad mein
# Warna NLB dangling rehta hai (AWS mein orphan)
helm uninstall s3-lister -n default
helm uninstall traefik -n traefik

cd iac/envs/dev
tofu --% destroy -var-file=dev.tfvars   # ~10-15 min

# Last step — state bucket + Docker Hub secret cleanup (fully done ke baad)
bash iac/bootstrap/teardown-state-backend.sh
```

> **Destroy order is strict:**
> 1. helm uninstall (NLB delete karo — cloud controller abhi alive hai)
> 2. tofu destroy (infra delete — VPC clear hogi kyunki NLB gone)
> 3. teardown-state-backend.sh (state bucket delete — tofu ab kaam nahi karega)
> State bucket pehle delete kiya → tofu state kho jaati hai → orphaned resources

---

## Concept Summary

| Concept | Key Point |
|---|---|
| IaC | Infrastructure as Code — repeatable, auditable, destroyable |
| OpenTofu | Terraform fork — BSL license → OpenTofu MPL 2.0 (Linux Foundation) |
| State | OpenTofu ki notebook — kya ban gaya ka record |
| Remote State | S3 + use_lockfile=true — no DynamoDB needed (OpenTofu 1.10+) |
| Provider | Plugin — OpenTofu → AWS API. Always pin version |
| Resource | Ek AWS cheez banao. References se dependency graph banta hai |
| Variable | Input — hardcode mat karo. tfvars se values do |
| Output | Module se bahar expose karo. Doosre modules use karte hain |
| Data Source | Read-only — existing cheez ki info lo, kuch banata nahi |
| Module | Reusable block — ek baar likho, multiple envs mein use karo |
| Community Module | terraform-aws-modules — battle-tested, production standard |
| Drift | Console se manual change — tofu plan detect karta hai |
| VPC Endpoints | NAT GW replace karo — 7 endpoints, S3 free, baaki Interface |
| EKS Addons | vpc-cni, coredns, kube-proxy, ebs-csi, pod-identity-agent, metrics-server |
| Pod Identity | pods.eks.amazonaws.com trust — no OIDC, no SA annotation, portable |
| Gateway API | GatewayClass + Gateway + HTTPRoute — 3 roles, Ingress replacement |
| Traefik | Gateway API first-class, hot reload, dashboard built-in, auto HTTPS |
| NGINX vs Traefik | NGINX = reload on change; Traefik = hot reload + Gateway API native |
| Traefik Dashboard | port 8080 — port-forward (dev), HTTPRoute+auth (staging), disable (prod) |
| ECR Pull-Through Cache | Docker Hub mirror in private ECR — no NAT GW needed, VPC endpoint se pull |
| Pull-Through Auth | Secret must be valid JSON: {"username":"...","accessToken":"..."} — no unquoted keys |
| Secret Format Bug | Shells often strip quotes when creating secrets — verify with get-secret-value |
| ECR Lifecycle Policy | Keep last N images — attach to repo explicitly (pull-through auto-creates repos) |
| Pre-create ECR Repos | aws_ecr_repository + depends_on pull-through rule — lifecycle policy needs repo to exist |
| AWS LBC vs In-tree | LBC = external+ip annotations (separate controller); In-tree = nlb annotation only |
| Gateway from: All | Traefik Gateway default from: Same — cross-namespace HTTPRoute needs from: All |
| Traefik Image via ECR | image.registry + image.repository separate — Helm prepends registry to repo |
| Gateway API CRDs | Traefik v3.7.1 needs v1.5.1 CRDs — standard-install.yaml (not v1.2.1) |
| Helm Chart | Chart.yaml + values.yaml + templates/ — template karo, hardcode mat karo |
| Helm Template Syntax | .Values.x, .Release.Name, toYaml\|nindent, include, if/end |
| Helm Commands | install, upgrade --install (idempotent), template (dry-run), rollback |
| Destroy Order | helm uninstall → tofu destroy → teardown-state-backend.sh (strict order) |
| State Bucket | Outside IaC — bootstrap script banata hai, teardown script delete karta hai |
| VPC Endpoint Delete Time | Interface endpoints = 1-2 min each — normal, not stuck |
| IGW Delete Delay | Internet Gateway = subnets clear hone ka wait karta hai |
