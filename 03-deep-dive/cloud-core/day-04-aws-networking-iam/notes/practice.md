# Day 4 Hands-on Notes — AWS Networking + IAM

---

## 1. VPC (Virtual Private Cloud)

### Hindi — Samajhne ke liye

AWS ka poora datacenter ek sheher hai. VPC = tera apna gated society. Baaki kisi ka traffic andar nahi aa sakta jab tak tu allow na kare.

```
Internet
    │
    ▼
Internet Gateway (IGW)        ← society ka main gate
    │
    ▼
VPC: 10.0.0.0/16              ← poori society (65,534 IPs)
    │
    ├── Public Subnet A  10.0.1.0/24  (AZ-1)  ← road-facing building (ALB, Bastion)
    ├── Public Subnet B  10.0.2.0/24  (AZ-2)  ← road-facing building (ALB)
    ├── Private Subnet A 10.0.3.0/24  (AZ-1)  ← andar wali building (EKS nodes, RDS)
    └── Private Subnet B 10.0.4.0/24  (AZ-2)  ← andar wali building (EKS nodes, RDS)
```

- **Public subnet** = IGW se direct route hai → internet aa-ja sakta hai
- **Private subnet** = Internet se seedha nahi — sirf NAT Gateway ke through bahar ja sakta hai
- **NAT Gateway** = Society ka "courier boy" — andar wale bahar bhej sakte hain, bahar wale seedha andar nahi aa sakte

### English — Interview Answer

> "A VPC is your logically isolated network inside AWS. You define the IP range using CIDR notation. Within a VPC, you create public and private subnets across multiple Availability Zones for high availability. The only difference between a public and private subnet is the route table — a public subnet has a route to an Internet Gateway (0.0.0.0/0 → IGW), a private subnet does not. Private subnets access the internet outbound-only through a NAT Gateway placed in the public subnet."

---

## 2. Security Groups vs NACLs

### Hindi — Samajhne ke liye

- **SG** = Har EC2 ka personal bodyguard (ENI level)
- **NACL** = Poore subnet ka gate guard

| | Security Group | NACL |
|---|---|---|
| Guards | Single EC2/pod | Entire subnet |
| State | **Stateful** (reply auto-allowed) | **Stateless** (reply bhi explicitly allow karo) |
| Rules | Allow only | Allow + Deny both |

**Stateful ka matlab (critical for interviews):**
- SG mein outbound 443 allow kiya → reply automatic aayegi, kuch aur nahi likhna
- NACL mein inbound 443 allow kiya → reply (ephemeral ports **1024–65535**) bhi outbound mein explicitly allow karni padegi. Bhool gaya? Connection hang karega.

### English — Interview Answer

> "Security Groups are stateful firewalls at the instance/ENI level — if you allow outbound 443, the return traffic is automatically allowed. NACLs are stateless and operate at the subnet level — you must explicitly allow both inbound and outbound, including ephemeral ports (1024–65535) for response traffic. Security Groups support allow rules only; NACLs support both allow and deny, which is useful for explicitly blocking a known bad IP at the subnet boundary."

---

## 3. VPC Endpoints

### Hindi — Samajhne ke liye

**Problem:** Private subnet mein EKS pod hai. S3 se data chahiye.
- Without endpoint: pod → NAT GW → Internet → S3 → NAT GW → pod
- Cost: NAT Gateway = $0.045/GB data processed + hourly charge

**With Gateway Endpoint (FREE):** pod → VPC Endpoint → S3 directly (AWS private network, internet nahi)

| Type | Works With | Cost |
|---|---|---|
| Gateway Endpoint | S3, DynamoDB ONLY | FREE (route table entry) |
| Interface Endpoint (PrivateLink) | Baaki sab AWS services | Paid (ENI create hoti hai) |

### English — Interview Answer

> "VPC Endpoints allow resources in a private subnet to reach AWS services without going through a NAT Gateway or the public internet. Gateway Endpoints are free and work with S3 and DynamoDB — they add a route table entry pointing to the endpoint. Interface Endpoints (PrivateLink) create an ENI inside your VPC and work with most other AWS services, but have an hourly cost. In production, we always add a Gateway Endpoint for S3 in private subnets to eliminate NAT Gateway data processing costs."

---

## 4. IAM — Identity and Access Management

### Hindi — Samajhne ke liye

- **User** = permanent employee — permanent access key milti hai
- **Role** = contractor — temporary credentials milti hain, khud expire hoti hain

> **NEVER:** EC2/Lambda/EKS pe IAM User credentials hardcode karo. Role use karo.

| Policy Type | Attached To | Example |
|---|---|---|
| Identity Policy | Role/User | "Ye kya kar sakta hai" |
| Resource Policy | S3/SQS pe directly | "Isse kaun access kar sakta hai" |
| SCP | AWS Organization | "Koi bhi CloudTrail band nahi kar sakta" |

**Trust Policy vs Permission Policy:**

```json
Trust Policy  → WHO can assume this role
"Principal": {"Service": "ec2.amazonaws.com"}

Permission Policy → WHAT they can do
"Action": "s3:GetObject"
"Resource": "arn:aws:s3:::my-bucket/*"
```

### English — Interview Answer

> "IAM Users have long-term credentials and should only be used for human access with MFA enforced. IAM Roles provide temporary credentials via STS and should be used for all service-to-service access — EC2 instance profiles, Lambda execution roles, EKS pods via IRSA. Every IAM role has two parts: a trust policy that defines who can assume the role, and a permission policy that defines what actions they can perform. I always follow least-privilege — grant only the specific actions and resources needed, never wildcard actions on wildcard resources in production."

---

## 5. IRSA — IAM Roles for Service Accounts

### Hindi — Samajhne ke liye

**Resume item — ye cold explain karna aana chahiye.**

**Problem:**
- EKS cluster mein 10 pods hain
- 3 ko S3 access chahiye, 2 ko DynamoDB, rest ko kuch nahi
- **Bad way:** Node IAM role mein sab permissions → 1 pod compromised = sab exposed
- **IRSA way:** Har ServiceAccount ko apni IAM role → granular, auditable

**Flow:**

```
1. EKS cluster → OIDC provider URL generate hoti hai
2. IAM role banao → Trust policy mein OIDC + specific namespace/ServiceAccount
3. K8s ServiceAccount annotate karo:
     eks.amazonaws.com/role-arn: arn:aws:iam::123456:role/s3-reader
4. Pod us SA se run karta hai → projected JWT token mount hota hai
5. AWS SDK → STS AssumeRoleWithWebIdentity → temp credentials → S3 access ✅
```

**Why better:**
- One pod compromised → sirf uska blast radius
- Node IAM role compromised → sab pods ka access gone

### English — Interview Answer

> "IRSA uses OIDC federation between EKS and AWS IAM. Each EKS cluster has an OIDC provider endpoint. You create an IAM role whose trust policy scopes access to a specific Kubernetes namespace and service account via that OIDC provider. When a pod runs with that service account, a projected JWT token is automatically mounted. The AWS SDK picks up this token, calls STS AssumeRoleWithWebIdentity, and gets short-lived temporary credentials. This gives you pod-level IAM granularity — far better than sharing a broad node IAM role across all pods."

---

## 6. IAM Policies — All 6 Types

### Basic Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
```

| Field | Matlab |
|---|---|
| `Effect` | Allow ya Deny |
| `Action` | Kya kar sakta hai — `s3:GetObject`, `ec2:*` |
| `Resource` | Kis cheez pe — specific ARN ya `*` |
| `Condition` | Extra conditions — MFA required, specific IP |

---

### Type 1 — Identity-Based Policy

**Kise attach:** IAM User, Group, Role  
**Kya define:** Ye identity kya kar sakti hai

| | Managed Policy | Inline Policy |
|---|---|---|
| Banata kaun | AWS ya tum | Tum — directly identity pe |
| Reuse | Multiple roles pe | Sirf ek identity ke liye |
| Recommended | ✅ Haan | ❌ Avoid karo |

- **AWS Managed** = `AmazonS3ReadOnlyAccess`, `AdministratorAccess`
- **Customer Managed** = Tumne banaye — least privilege ke liye best

---

### Type 2 — Resource-Based Policy

**Kise attach:** Resource pe directly (S3 bucket, SQS, KMS key)  
**Kya define:** Is resource ko kaun access kar sakta hai  
**Key difference:** `Principal` field hota hai — WHO specify karte hain  
**Use case:** Cross-account access

```json
{
  "Principal": "arn:aws:iam::999999:role/other-account-role",
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*"
}
```

---

### Type 3 — Permissions Boundary

**Kya hai:** IAM entity ke liye maximum permissions ki ceiling

```
Role ki actual permissions:  s3:*, ec2:*, rds:*
Permissions Boundary:        sirf s3:* allow
Result: Role sirf S3 access kar sakti hai — chahe identity policy mein ec2 allow ho
```

**Use case:** Junior devs ko IAM roles banane do — but wo apni roles ko admin nahi bana sakte

**English:**
> "Permissions boundary sets the maximum permissions an IAM entity can have. Even if the identity policy allows broader access, the effective permissions are the intersection of the identity policy and the boundary. Used to delegate IAM administration safely."

---

### Type 4 — SCP (Service Control Policy)

**Kaha lagti hai:** AWS Organizations — account ya OU level pe  
**Kya karti hai:** Poore AWS account ki maximum permissions define karti hai

```
Organization Root
    └── OU: Production
         └── SCP: "CloudTrail disable karna banned"
              └── AWS Account: prod-account
                   └── Chahe Admin bhi ho — CloudTrail band nahi kar sakta
```

**Key point:** SCP allow nahi deti — sirf **guardrails** lagati hai

**English:**
> "SCPs are guardrails applied at the AWS Organization level. They don't grant permissions — they restrict the maximum permissions available in an account. Even an account root user cannot perform actions denied by an SCP. Used to enforce compliance — for example, preventing any account from disabling CloudTrail or creating resources outside approved regions."

---

### Type 5 — Session Policy

**Kab use:** `AssumeRole` call ke time — temporary session ke liye

```
Role ki full permissions: s3:*, ec2:*
Session Policy pass karo: sirf s3:GetObject
Us session mein sirf s3:GetObject kaam karega
```

**Use case:** IRSA mein STS AssumeRoleWithWebIdentity ke saath — pod ko scoped permissions

---

### Type 6 — ACL (Access Control List)

- S3 ke liye: **deprecated** — bucket policies use karo
- VPC NACLs: networking layer pe hain, IAM se alag

---

### Priority Order — Conflict mein kaun jeeta

```
1. Explicit DENY    → koi bhi policy mein deny? DONE. Access blocked.
2. SCP              → organization level allow hai?
3. Resource Policy  → resource ne allow kiya?
4. Identity Policy  → identity ko allow hai?
5. Permissions Boundary → boundary ke andar hai?
6. Session Policy   → session mein allow hai?

Sab pass → ACCESS GRANTED ✅
Koi ek fail → ACCESS DENIED ❌
```

---

### Kab Kya Use Karo

| Situation | Policy Type |
|---|---|
| EC2 ko S3 access dena | Identity-based (Role) |
| Dusre account ko bucket access | Resource-based (Bucket Policy) |
| Dev ko IAM banana do but limit karo | Permissions Boundary |
| Poore org mein CloudTrail protect karo | SCP |
| Pod ko limited AWS access | Identity-based + IRSA |
| Temporary scoped access | Session Policy |

### English — Interview Answer

> "AWS has 6 policy types. Identity-based policies attach to users/roles and define what they can do. Resource-based policies attach to resources like S3 and define who can access them — they include a Principal field and are commonly used for cross-account access. Permissions boundaries cap the maximum permissions a role can have, useful for safe IAM delegation. SCPs are organization-level guardrails that restrict entire AWS accounts — even the root user cannot bypass an SCP deny. Session policies scope permissions during an AssumeRole call for that session only. All policies evaluate together — an explicit deny anywhere always wins regardless of what other policies allow."

---

## Hands-On — What Was Done

### Step 1 — VPC Created ✅

Used **"VPC and more"** option — AWS auto-created everything:

| Resource | ID |
|---|---|
| VPC | `vpc-0b3ef75987ebd61cf` |
| Internet Gateway | `igw-0bfff169be1484336` |
| S3 Gateway Endpoint | `vpce-0d48d3ad70015b9ac` |
| Subnets | 4 total (2 public, 2 private, 2 AZs) |
| Route Tables | 3 (1 public → IGW, 2 private → local + S3 endpoint) |

- NAT Gateway: **NOT created** (cost saving)
- S3 Endpoint: **auto-associated** with private route tables

---

### Step 2 — EC2 Launch ✅

**What happened:**
- EC2 `devops-lab-vm` launched in **private subnet** (`subnet-0da15a099f010105f — devops-lab-subnet-private2-us-east-1b`)
- Instance ID: `i-0e2b1bfdbb53c85e3`
- Private IP: `10.0.159.203`
- Public IP was assigned (`54.80.208.140`) but SSH timed out — **private subnet has no IGW route**
- Key pair: `devops-lab-vm-key.pem` (stored in Downloads)

**What we learned:**
- Private subnet mein public IP hone ke bawajood SSH nahi hota — route table mein IGW entry nahi hoti
- SSH timeout = SG issue nahi, routing issue tha

**Bastion concept:**
```
Internet
    │
    ▼
Bastion Host (Public Subnet)   ← Jump server — single controlled entry point
    │ SSH
    ▼
Private EC2 (Private Subnet)   ← Actual server — never exposed to internet directly
```

**Why bastion / Session Manager:**
- Private EC2 direct internet se reachable nahi — intentional security
- Bastion = SSH ke liye, Session Manager = modern way (no SSH port needed)

---

### Step 3 — Session Manager Connect (attempted)

**Why Session Manager over SSH:**
- No port 22 open karna padta
- No key pair manage karna padta
- Full audit trail in CloudTrail
- Works even in private subnet — SSM Agent polls AWS endpoint outbound

**Steps:**
1. IAM Role banao → Trusted entity: EC2 → Policy: `AmazonSSMManagedInstanceCore`
2. EC2 → Actions → Security → Modify IAM Role → attach role
3. EC2 Console → Connect → **Session Manager tab** → Connect

**Note:** Amazon Linux 2023 mein SSM Agent pre-installed hota hai.

**IAM Permission fix karo (one time on Windows):**
```bash
icacls "C:\Users\Sameer\Downloads\devops-lab-vm-key.pem" /inheritance:r /grant:r "%USERNAME%:R"
```

---

### Step 4 — S3 Endpoint ✅ (DONE via VPC wizard)

S3 Gateway endpoint already created: `vpce-0d48d3ad70015b9ac`
Associated with private route tables automatically.

---

### Step 5 — IRSA POC (pending — needs EKS cluster)

```bash
# Install eksctl
eksctl create cluster --name irsa-lab --region us-east-1 --nodes 1
eksctl utils associate-iam-oidc-provider --cluster irsa-lab --approve

# Create IAM role scoped to SA
# Annotate ServiceAccount
# Deploy test pod → aws s3 ls inside pod

# CLEANUP (mandatory)
eksctl delete cluster --name irsa-lab
```

---

### Cleanup — What Costs Money

```
EC2 instances  → TERMINATE (not stop — stopped EC2 still charges EBS)
NAT Gateway    → not created — skip
Elastic IP     → not created — skip
VPC/Subnets/IGW/SG/Route Tables → FREE — can keep
```

**Only EC2 costs money — terminate karo, bill zero.**

---

## Observations

| | |
|---|---|
| VPC ID | `vpc-0b3ef75987ebd61cf` |
| S3 Endpoint ID | `vpce-0d48d3ad70015b9ac` |
| IGW ID | `igw-0bfff169be1484336` |
| EC2 Instance ID | `i-0e2b1bfdbb53c85e3` |
| EC2 Subnet | `devops-lab-subnet-private2-us-east-1b` |
| EC2 Private IP | `10.0.159.203` |
| SSH result | Timeout — private subnet, no IGW route |
| Session Manager | IAM role needed — `AmazonSSMManagedInstanceCore` |
| EC2 terminated at | |
