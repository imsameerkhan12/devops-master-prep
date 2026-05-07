# Day 4: AWS Networking + IAM

## VPC Architecture

```
VPC (10.0.0.0/16)
├── Public Subnet A (10.0.1.0/24) — AZ-1  ← ALB, Bastion
├── Public Subnet B (10.0.2.0/24) — AZ-2  ← ALB
├── Private Subnet A (10.0.3.0/24) — AZ-1  ← EKS nodes, RDS
└── Private Subnet B (10.0.4.0/24) — AZ-2  ← EKS nodes, RDS

Internet Gateway  → attached to VPC
NAT Gateway       → in public subnet → private subnets route default (0.0.0.0/0) through it
Route Table Public → 0.0.0.0/0 → IGW
Route Table Private → 0.0.0.0/0 → NAT GW
```

**Production pattern:** 2 public + 2 private subnets across 2 AZs minimum.

---

## Security Groups vs NACLs

| | Security Group | NACL |
|-|---------------|------|
| Level | Instance/ENI | Subnet |
| State | **Stateful** (return traffic auto-allowed) | **Stateless** (both inbound + outbound explicit) |
| Rules | Allow only | Allow + Deny |
| Default | Allow all outbound, deny all inbound | Allow all |

**Interview gotcha:** SG outbound 443 allow → response automatically allowed back.  
NACL: must explicitly allow inbound ephemeral ports (1024-65535) for responses.

---

## VPC Endpoints

| Type | Services | Cost | How |
|------|---------|------|-----|
| Gateway | S3, DynamoDB | FREE | Route table entry |
| Interface (PrivateLink) | All other AWS services | Paid (ENI created) | DNS resolution |

**Use case:** Private subnet EKS pod → S3 without going through NAT Gateway (saves $0.045/hr).

---

## IAM Deep

### User vs Role
- **User** = long-term credentials (humans, API keys)
- **Role** = temporary credentials (services, cross-account, EC2, Lambda, EKS pods)

### Policy Types
| Type | Attached To | Example |
|------|------------|---------|
| Identity-based | User/Role | "This role can read S3" |
| Resource-based | Resource (S3/SQS) | "Only this role can access this bucket" |
| SCP | AWS Organization | "No account can disable CloudTrail" |

### Trust Policy vs Permission Policy
- **Trust policy:** WHO can assume this role (e.g., EKS service account, EC2, another account)
- **Permission policy:** WHAT the role can do (e.g., s3:GetObject on arn:aws:s3:::my-bucket/*)

---

## IRSA — IAM Roles for Service Accounts (YOUR RESUME ITEM)

**What:** Give individual K8s pods AWS permissions without sharing node IAM role.

### Flow (5 Steps)
```
1. EKS cluster has OIDC provider URL (https://oidc.eks.region.amazonaws.com/id/XXXXX)
2. Create IAM role with trust policy: allows token.k8s.aws/oidc → specific namespace/SA
3. Annotate K8s ServiceAccount:
   annotations:
     eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/my-role
4. Pod using that SA gets projected token mounted at /var/run/secrets/eks.amazonaws.com/serviceaccount/token
5. AWS SDK auto-calls STS AssumeRoleWithWebIdentity → gets temp credentials
```

### Why Better Than Node IAM Role
- **Node IAM role:** ALL pods on the node share same permissions — blast radius huge
- **IRSA:** Per-pod granularity, one pod compromised ≠ all pods compromised
- Audit trail in CloudTrail per SA

---

## Hands-on Checklist
- [ ] Create VPC: 2 pub + 2 priv subnets, IGW, NAT GW — draw diagram
- [ ] Launch EC2 in private subnet, SSH via bastion
- [ ] Create IAM role with S3 read-only, `aws sts assume-role` test from CLI
- [ ] EKS cluster → setup IRSA → pod lists S3 buckets
- [ ] **DESTROY NAT Gateway at end** — $0.045/hr idle = $32/month!
