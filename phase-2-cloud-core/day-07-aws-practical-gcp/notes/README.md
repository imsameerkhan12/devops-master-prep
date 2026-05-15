# Day 7: AWS Practical + GCP Touch

## HA Web App Architecture

```
Internet
  └── Route53 (DNS, health checks, failover routing)
        └── CloudFront (CDN, TLS termination, edge caching)
              └── ALB (L7, path routing, WAF)
                    ├── EKS Node Group A (AZ-1)
                    │     └── Pods
                    └── EKS Node Group B (AZ-2)
                          └── Pods
                              ├── RDS Multi-AZ (primary + standby)
                              └── ElastiCache (Redis, session store)
```

---

## Multi-Region DR Strategies

| Pattern | RTO | RPO | Cost | Use When |
|---------|-----|-----|------|---------|
| Active-Active | ~0 | ~0 | Highest | Zero downtime required |
| Active-Passive (Warm) | ~5 min | Seconds | Medium | Most production apps |
| Pilot Light | 30-60 min | Minutes | Low | Non-critical apps |
| Backup-Restore | Hours | Hours | Lowest | Dev/test, archives |

**Most common in interviews:** Active-Passive with Aurora Global DB + Route53 health checks.

---

## AWS Well-Architected Framework — 6 Pillars

1. **Operational Excellence** — Automate operations, learn from failures, runbooks
2. **Security** — Least privilege, encryption, detect threats (GuardDuty, Security Hub)
3. **Reliability** — Multi-AZ, auto-recovery, chaos engineering, backups
4. **Performance Efficiency** — Right-sizing, serverless, managed services, benchmarking
5. **Cost Optimization** — Spot, Savings Plans, S3 lifecycle, delete unused resources
6. **Sustainability** — Efficient resource use, minimize footprint

**Interview tip:** When asked "how would you design X?" — mention relevant pillars. Shows structured thinking.

---

## Cost Optimization Levers

### Compute
- **Spot:** 90% off, but 2-min interruption warning. Use for stateless, batch, Spark.
- **Savings Plans:** 1 or 3-year commit, 30-50% off. Flexible (applies to any EC2/Fargate/Lambda).
- **Reserved Instances:** Legacy, less flexible than Savings Plans.
- **Karpenter:** Auto-mixes Spot + On-demand, auto-consolidates nodes.

### Storage
- S3 lifecycle → move old data to IA/Glacier
- EBS: `gp3` over `gp2` (cheaper + better IOPS)
- Delete unattached EBS volumes (easy win!)

### Network
- NAT Gateway = $0.045/hr + $0.045/GB data. Replace with VPC Gateway Endpoints for S3/DynamoDB.
- CloudFront reduces data transfer costs from origin.

### Tools
- **Cost Explorer** — visualize spend, filter by service/tag
- **Trusted Advisor** — idle resources, security issues
- **Compute Optimizer** — EC2/Lambda right-sizing recommendations

---

## GCP Touch — GKE Basics

### GKE Standard vs Autopilot
| | Standard | Autopilot |
|-|----------|-----------|
| Node management | You manage | Google manages |
| Billing | Per node | **Per pod** (cheaper for sparse workloads) |
| DaemonSets | Yes | Limited |

### GCP Equivalents
- **Workload Identity** = IRSA equivalent (K8s SA → Google Service Account)
- **Cloud SQL** = Managed Postgres/MySQL (like RDS)
- **Artifact Registry** = ECR equivalent
- **Cloud Armor** = WAF (like AWS WAF)

---

## Cross-Cloud K8s Comparison

| | EKS | AKS | GKE |
|-|-----|-----|-----|
| Control plane cost | $73/month | **FREE** | Free (Standard), Autopilot per-pod |
| Networking | VPC CNI | Azure CNI / Kubenet | VPC-native |
| Identity | IRSA (EKS OIDC) | Workload Identity (AAD) | Workload Identity (GSA) |
| Autoscaling | Karpenter / CA | Cluster Autoscaler | Autopilot / CA |
| Managed upgrade | Semi-manual | Mostly managed | Mostly managed |

---

## Hands-on Checklist
- [ ] Draw HA architecture for "e-commerce, 100K users, IN + US" on paper
- [ ] GKE Autopilot cluster — 1 hour, then destroy
- [ ] Terraform script for AWS VPC (reusable)
