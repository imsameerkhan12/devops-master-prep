# Day 5: AWS Compute + Storage + EKS Deep

## EC2 Instance Types (Know the Family, Not Every Type)

| Family | Optimized For | Example Use |
|--------|--------------|-------------|
| t | Burstable (CPU credits) | Dev, low-traffic |
| m | General purpose | Web servers, app servers |
| c | Compute | CI/CD runners, batch |
| r | Memory | Databases, caching |
| p/g | GPU | ML training |

---

## Storage Comparison

| | EBS | EFS | S3 |
|-|-----|-----|----|
| Type | Block | NFS (network file) | Object |
| Scope | Single AZ, one EC2 | Multi-AZ, many EC2s | Global (URL-based) |
| Use case | OS disk, DB | Shared config, K8s ReadWriteMany | Artifacts, backups, static files |

### EBS Volume Types
- `gp3` — default, cost-effective, 3000 IOPS baseline (better than gp2!)
- `io2` — high IOPS, mission-critical DBs
- `st1` — throughput-optimized HDD, big data/log processing

---

## S3 Deep

### Storage Classes (Cost ↓, Retrieval Time ↑)
```
Standard → Standard-IA → One Zone-IA → Glacier Instant → Glacier Flexible → Deep Archive
```

### Lifecycle Policy Example
```json
{
  "Rules": [{
    "Status": "Enabled",
    "Transitions": [
      {"Days": 30, "StorageClass": "STANDARD_IA"},
      {"Days": 90, "StorageClass": "GLACIER"}
    ],
    "Expiration": {"Days": 365}
  }]
}
```

### Access Control (3 Mechanisms)
1. **Bucket Policy** (resource-based) — preferred for cross-account + public access
2. **IAM Policy** (identity-based) — for within-account control
3. **ACL** (legacy) — avoid, use policies instead

### Encryption
- `SSE-S3` — AWS manages key, transparent
- `SSE-KMS` — You control key rotation, audit in CloudTrail
- `SSE-C` — You provide key on every request

### Pre-signed URL
Temporary public access without making bucket public:
```bash
aws s3 presign s3://my-bucket/file.zip --expires-in 3600
```

---

## EKS Architecture

### Control Plane (AWS Managed)
- API server, etcd, scheduler, controller-manager
- Cost: **$73/month per cluster** — always running
- HA across 3 AZs built-in

### Data Plane Options

| | Managed Node Groups | Fargate | Self-managed |
|-|--------------------|---------| -------------|
| Nodes | EC2, AWS manages AMI | No nodes | EC2, you manage |
| DaemonSets | Yes | **No** | Yes |
| Cost | EC2 pricing | Per-pod (slightly more) | EC2 pricing |
| Use | Most workloads | Stateless, no DaemonSets | Custom AMI needed |

---

## EKS Networking (VPC CNI)

- Each pod gets a **real VPC IP** (no NAT, fast networking)
- ENI limit per instance = IP limit per node
  - `m5.large` = 3 ENIs × 10 IPs = **29 pods max** (1 reserved)
- Alternative: **Cilium CNI** (eBPF, better performance, network policy built-in)

---

## Cluster Autoscaler vs Karpenter

| | Cluster Autoscaler (CA) | Karpenter |
|-|------------------------|-----------|
| Mechanism | Scales ASG node groups | Directly provisions EC2 |
| Speed | 2–10 minutes | **~30 seconds** |
| Instance types | One per node group | Multiple in one config |
| Spot + On-demand | Complex setup | Native mixing |
| 2025-26 trend | Legacy | **Preferred — learn this** |

**Interview gold:** "We use Karpenter because it provisions nodes in 30s vs CA's 2-10 min, supports multi-instance-type in a single NodePool, and natively mixes Spot + On-demand without separate ASGs."

---

## 3 End-of-Day Q&A

**Q1: Pod ko external traffic kaise milta hai (full flow)?**  
Internet → Route53 → ALB (LoadBalancer Service or Ingress) → K8s Service (ClusterIP) → iptables/kube-proxy → Pod IP

**Q2: Node group upgrade — 5 steps?**  
1. Update launch template with new AMI  
2. Create new node group with updated template  
3. Cordon old nodes (`kubectl cordon`)  
4. Drain old nodes (`kubectl drain --ignore-daemonsets --delete-emptydir-data`)  
5. Delete old node group after pods reschedule

**Q3: Karpenter vs CA — 3 differences?**  
1. Karpenter = 30s provisioning vs CA = 2-10 min  
2. Karpenter uses single NodePool with multi-instance types vs CA = one ASG per instance type  
3. Karpenter directly calls EC2 API vs CA needs ASG pre-defined
