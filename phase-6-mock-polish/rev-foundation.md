# Foundation Cheatsheet
> Linux · Networking · AWS Core · IAM · HA + DR

---

## Linux Essentials

### Permissions
```bash
chmod 755 file        # owner=rwx, group+others=rx
chmod u+x file        # add execute for user
# SUID=4xxx  SGID=2xxx  Sticky=1xxx
# /tmp has sticky bit — only owner can delete their files
```

### Process Management
```bash
ps aux | grep nginx   # find process
kill -15 PID          # SIGTERM — graceful (app cleans up)
kill -9 PID           # SIGKILL — immediate, no cleanup
# K8s pod termination: SIGTERM → grace period (30s default) → SIGKILL
```

### Networking Commands
```bash
ss -tunlp             # listening ports (modern netstat)
lsof -i :8080         # what process on port 8080
dig +trace google.com # DNS: root → TLD → authoritative
curl -v https://url   # verbose HTTP — shows TLS handshake
tcpdump -i any port 443
journalctl -u kubelet -f   # follow kubelet logs (EKS node debug gold)
```

### Safe Script Header
```bash
#!/bin/bash
set -euo pipefail
# -e: exit on error | -u: error on undefined var | -o pipefail: pipe errors count
```

### 20 Commands Cheatsheet
| Command | What |
|---------|------|
| `chmod 755` | rwx for owner, rx for group/others |
| `chown user:group file` | change ownership |
| `ps aux \| grep` | find process |
| `kill -15 / -9` | SIGTERM / SIGKILL |
| `ss -tunlp` | listening ports |
| `lsof -i :PORT` | process on port |
| `dig +trace domain` | full DNS trace |
| `curl -v URL` | verbose HTTP |
| `journalctl -u svc -f` | follow service logs |
| `systemctl status svc` | service status |
| `df -h` | disk space |
| `du -sh /path` | dir size |
| `free -h` | memory |
| `top -bn1` | CPU snapshot |
| `netstat -rn` | routing table |
| `strace -p PID` | syscall trace |
| `tcpdump -i any port 80` | packet capture |
| `umask 022` | default perms |
| `trap 'cleanup' EXIT` | cleanup on exit |
| `set -euo pipefail` | safe script |

---

## Networking

### OSI — DevOps Relevant Layers
| Layer | Protocol | DevOps |
|-------|----------|--------|
| L3 Network | IP | VPC, subnets, SG, routing |
| L4 Transport | TCP/UDP | NLB, port filtering |
| L7 Application | HTTP/HTTPS | ALB, Ingress, WAF |

### TCP vs UDP
| | TCP | UDP |
|-|-----|-----|
| Connection | 3-way handshake (SYN→SYN-ACK→ACK) | None |
| Reliability | Guaranteed + ordered | Best-effort |
| Use | HTTP, SSH, DB | DNS, video, gaming |

### DNS Record Types
| Record | Use |
|--------|-----|
| A | domain → IPv4 |
| AAAA | domain → IPv6 |
| CNAME | alias to another name |
| MX | mail server |
| TXT | SPF, DKIM, domain verification |

**DNS Flow:** Browser cache → OS cache → ISP resolver → Root → TLD → Authoritative → Answer

### HTTP Status Codes
| Range | Meaning | Key |
|-------|---------|-----|
| 2xx | Success | 200 OK |
| 3xx | Redirect | 301 permanent, 302 temp |
| 4xx | Client error | 401 auth, 403 forbidden, 404 not found, 429 rate limit |
| 5xx | Server error | 500 internal, 502 bad gateway, 503 unavailable, 504 timeout |

### L4 vs L7 Load Balancer
| | L4 (NLB) | L7 (ALB) |
|-|----------|----------|
| Level | TCP/UDP | HTTP/HTTPS |
| Speed | Faster | Smarter |
| Features | Port-level | Path routing, headers, WAF |

### CIDR Quick Reference
| CIDR | Total IPs | Usable |
|------|-----------|--------|
| /24 | 256 | 254 |
| /20 | 4,096 | 4,094 |
| /16 | 65,536 | 65,534 |

Formula: `2^(32 - prefix) - 2`

---

## AWS Core

### VPC Architecture
```
VPC (10.0.0.0/16)
├── Public Subnet A  (10.0.1.0/24) — AZ1  ← ALB, Bastion
├── Public Subnet B  (10.0.2.0/24) — AZ2
├── Private Subnet A (10.0.3.0/24) — AZ1  ← EKS nodes, RDS
└── Private Subnet B (10.0.4.0/24) — AZ2

Internet Gateway  → VPC (public internet access)
NAT Gateway       → Public subnet → private subnets route through it
Route Table Pub   → 0.0.0.0/0 → IGW
Route Table Priv  → 0.0.0.0/0 → NAT GW
```

### Security Groups vs NACLs
| | Security Group | NACL |
|-|---------------|------|
| Level | Instance/ENI | Subnet |
| State | **Stateful** (return auto-allowed) | **Stateless** (both directions explicit) |
| Rules | Allow only | Allow + Deny |

**Gotcha:** SG outbound 443 → response auto-allowed. NACL: must allow inbound ephemeral 1024-65535.

### VPC Endpoints
| Type | Services | Cost |
|------|---------|------|
| Gateway | S3, DynamoDB | FREE |
| Interface (PrivateLink) | All others | Paid (ENI) |

**Win:** Private subnet pods → S3 via Gateway endpoint = no NAT Gateway cost.

### IAM Basics
- **User** = long-term creds (humans)
- **Role** = temp creds (services, EC2, EKS pods)
- **Trust Policy** = WHO can assume the role
- **Permission Policy** = WHAT the role can do
- **SCP** = org-level guardrails (even account admins can't bypass)

### IRSA — IAM Roles for Service Accounts
```
1. EKS cluster has OIDC provider URL
2. IAM role trust policy: allows specific namespace + SA
3. K8s ServiceAccount annotated with role ARN
4. Pod using SA gets projected token
5. AWS SDK → STS AssumeRoleWithWebIdentity → temp creds
```
**Why better than node role:** per-pod permissions, blast radius = zero on compromise.

### Parameter Store vs Secrets Manager
| | Parameter Store | Secrets Manager |
|-|----------------|----------------|
| Cost | Standard = FREE | $0.40/secret/month |
| Rotation | Manual | Auto-rotation built-in |
| Use | Config, static secrets | DB passwords, API keys |

---

## HA + Cost + DR

### HA Architecture
```
Internet → Route53 (health checks + failover routing)
→ CloudFront (CDN + TLS termination + edge cache)
→ ALB (L7, path routing, WAF)
  ├── EKS Node Group A (AZ1) → Pods
  └── EKS Node Group B (AZ2) → Pods
      ├── RDS Multi-AZ (synchronous replication, 60s auto-failover)
      └── ElastiCache Redis (session store)
```

### DR Strategies
| Pattern | RTO | RPO | Use When |
|---------|-----|-----|---------|
| Active-Active | ~0 | ~0 | Zero downtime required |
| Active-Passive (Warm) | ~5 min | Seconds | Most prod apps |
| Pilot Light | 30-60 min | Minutes | Non-critical |
| Backup-Restore | Hours | Hours | Dev/test |

### AWS Well-Architected — 6 Pillars
1. **Operational Excellence** — runbooks, automate operations
2. **Security** — least privilege, GuardDuty, encryption
3. **Reliability** — multi-AZ, chaos engineering, backups
4. **Performance Efficiency** — right-sizing, serverless
5. **Cost Optimization** — Spot, Savings Plans, S3 lifecycle
6. **Sustainability** — efficient resource use

### Cost Optimization Levers
- **Spot instances:** 90% off, 2-min interruption warning — stateless/batch only
- **Savings Plans:** 1 or 3-yr commit, 30-50% off, flexible
- **Karpenter:** auto-consolidates underutilized nodes
- **VPC Gateway Endpoints:** S3/DynamoDB without NAT Gateway ($0.045/hr saved)
- **EBS gp3 over gp2:** cheaper + better IOPS
- Delete unattached EBS volumes, old snapshots, idle NAT Gateways

### RDS Multi-AZ vs Read Replica
| | Multi-AZ | Read Replica |
|-|----------|-------------|
| Replication | **Synchronous** | Asynchronous (lag) |
| Purpose | HA + auto-failover | Read scaling |
| Cross-region | No | Yes |

---

## IAM Deep Dive — All 6 Types

### Basic JSON Structure
```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::my-bucket/*",
  "Condition": { "Bool": { "aws:MultiFactorAuthPresent": "true" } }
}
```

### 6 Types — When + Why
| # | Type | Attached To | Has Principal? | Use Case |
|---|------|------------|----------------|----------|
| 1 | **Identity-based** | User/Role/Group | No | What identity can do |
| 2 | **Resource-based** | S3/SQS/KMS etc | **Yes** | Who can access this resource (cross-account) |
| 3 | **Permissions Boundary** | User/Role | No | MAX ceiling — can't exceed even if identity policy allows |
| 4 | **SCP** | AWS Org Account/OU | No | Org-level guardrails — even root can't bypass |
| 5 | **Session Policy** | AssumeRole call | No | Scope down temp session |
| 6 | **ACL** | S3 (legacy) | Special | Deprecated — use bucket policy instead |

### Priority Order
```
1. Explicit DENY    → anywhere? BLOCKED. Period.
2. SCP              → org allow karta hai?
3. Resource Policy  → resource ne allow kiya?
4. Identity Policy  → identity ko allow hai?
5. Permissions Boundary → ceiling ke andar hai?
6. Session Policy   → session scope mein hai?

All pass → ACCESS GRANTED ✅   Any fail → DENIED ❌
```

### Permissions Boundary
```
Role actual perms: s3:*, ec2:*, rds:*
Boundary says:     ONLY s3:*
Effective:         ONLY s3:* (intersection)

Use: Junior devs make IAM roles, but boundary stops them from granting themselves admin
```

### SCP Example
```
Production OU SCP:
  Deny: cloudtrail:StopLogging, cloudtrail:DeleteTrail
  Even Account Admin cannot stop CloudTrail
  Even root user blocked by SCP deny

SCP ≠ grant permissions. SCP = maximum allowed ceiling.
```

### IAM Role vs User
```
IAM User = permanent employee — long-term access key (leak risk)
IAM Role = contractor — STS temp creds, auto-expire
           Assigned to: EC2, Lambda, EKS pods (IRSA/Pod Identity)

NEVER hardcode IAM User keys in app/EC2/EKS — always use Role
```
