# MASTER REVISION GUIDE
> One file. Everything. Scan fast, revise fast.

---

## QUICK NAV
- [STAR Stories](#1-star-stories)
- [Linux](#2-linux-essentials)
- [Networking](#3-networking)
- [AWS Core](#4-aws-core)
- [EKS Deep](#5-eks-deep)
- [Secrets Management](#6-secrets-management)
- [HA + Cost + DR](#7-ha--cost--dr)
- [K8s Pod Lifecycle](#8-k8s-pod-lifecycle)
- [K8s Networking + Storage + RBAC](#9-k8s-networking--storage--rbac)
- [Helm + Troubleshooting](#10-helm--troubleshooting)
- [Autoscaling](#11-autoscaling)
- [Advanced K8s](#12-advanced-k8s)
- [GitOps — ArgoCD](#13-gitops--argocd)
- [External Secrets Operator](#14-external-secrets-operator)
- [OpenTofu / IaC](#15-opentofu--iac)
- [CI/CD — GitHub Actions + Azure DevOps](#16-cicd--github-actions--azure-devops)
- [Observability](#17-observability)
- [cert-manager](#18-cert-manager)
- [Hands-On Tasks](#19-hands-on-tasks)
- [Interview Q&A Rapid Fire](#20-interview-qa-rapid-fire)
- [Conceptual Analogies — Hindi](#21-conceptual-analogies--hindi)
- [IAM Deep Dive — All 6 Types](#22-iam-deep-dive--all-6-types)
- [Private EKS Debug Log — Real Incidents](#23-private-eks-debug-log--real-incidents)
- [Production Gotcha Patterns](#24-production-gotcha-patterns)
- [Lab Runbook — Actual Commands](#25-lab-runbook--actual-commands)

---

## 1. STAR Stories

**Format:** Situation → Task → Action → Result (numbers required, 2 min max)

| # | Story | Key Result |
|---|-------|-----------|
| 1 | **Vault → SSM Migration** (Compliance Innovation) | 50+ services, zero downtime, cost reduction |
| 2 | **Docker Compose → Helm** (Indicios) | Multi-env parity, reduced deploy time |
| 3 | **Production Incident** | Fill with real incident — RCA + resolution time |
| 4 | **Cross-team Disagreement** | GitOps proposal — dev access + security RBAC |
| 5 | **Database DevOps** (Victra) | SSDT + Azure DevOps, faster + fewer prod issues |
| 6 | **Why Leaving** (TokenTide) | Seeking larger scale + stronger engineering culture |

**Tell Me About Yourself (memorize):**
> "I'm a DevOps engineer with 5 years of experience across AWS, Kubernetes, and CI/CD. At Compliance Innovation I worked on secrets migration from Vault to AWS SSM using External Secrets Operator, and containerized workloads from Docker Compose to Helm on EKS. Before that at Cybage I built Database DevOps pipelines for a US telecom client using SSDT and Azure DevOps, and GraphQL gateways with HotChocolate. I hold the CKA and AZ-204. I'm looking for a role where I can work on platform engineering at scale."

---

## 2. Linux Essentials

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

## 3. Networking

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
| | L4 (NLB) | L7 (ALB, Nginx) |
|-|----------|----------------|
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

## 4. AWS Core

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

### IAM
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

## 5. EKS Deep

### Control Plane
- AWS managed: API server, etcd, scheduler, controller-manager
- Cost: **$73/month** per cluster
- HA across 3 AZs built-in

### Data Plane Options
| | Managed Node Groups | Fargate | Self-managed |
|-|--------------------|---------|-------------|
| DaemonSets | Yes | **No** | Yes |
| Use | Most workloads | Stateless only | Custom AMI |

### EKS Networking (VPC CNI)
- Each pod gets a **real VPC IP** — no NAT
- ENI limit per instance type = pod limit per node
- `m5.large` = 3 ENIs × 10 IPs = **29 pods max**

### Cluster Autoscaler vs Karpenter
| | Cluster Autoscaler | Karpenter |
|-|-------------------|-----------|
| Speed | 2-10 min | **< 60 seconds** |
| Instance types | One per node group | Multi in one NodePool |
| Spot mixing | Complex | Native |
| 2026 status | Legacy | **Preferred on EKS** |

**Interview gold:** "Karpenter provisions nodes in < 60s vs CA's 2-10 min, supports multi-instance-type in one NodePool, natively mixes Spot + On-demand, and consolidates underutilized nodes automatically."

### Traffic Flow: Internet → Pod
```
Internet → Route53 → ALB (L7, TLS termination)
→ K8s Service (LoadBalancer) → kube-proxy iptables
→ Pod IP (real VPC IP via VPC CNI) → container port

With Ingress:
Internet → ALB → Ingress Controller (NGINX/Traefik) → ClusterIP Service → Pod
```

### Storage Comparison
| | EBS | EFS | S3 |
|-|-----|-----|----|
| Type | Block | NFS | Object |
| Access | Single AZ, 1 node | Multi-AZ, many nodes | Global (URL) |
| K8s mode | RWO | RWX | — |
| Use | OS, DB | Shared config | Artifacts, backups |

---

## 6. Secrets Management

### ESO — External Secrets Operator
```yaml
# ClusterSecretStore — WHERE to get secrets
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa   # IRSA for AWS access

---
# ExternalSecret — WHAT to sync
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-secret             # K8s Secret created here
  data:
  - secretKey: password         # key in K8s Secret
    remoteRef:
      key: prod/db/password     # path in AWS Secrets Manager
```
**Result:** `db-secret` auto-created + refreshed every 1h. App uses it as normal Secret. No secrets in Git.

### K8s Secrets — What You Must Know
```yaml
apiVersion: v1
kind: Secret
data:
  password: cGFzc3dvcmQxMjM=   # base64 — NOT encrypted!
```
**Critical:** base64 is encoding, not encryption. Anyone with `kubectl get secret` can decode.
**Rule:** Never put real secret values in Git. Use ESO → AWS SM.

---

## 7. HA + Cost + DR

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

## 8. K8s Pod Lifecycle

### Pod Phases
| Phase | Meaning |
|-------|---------|
| Pending | Not scheduled (no resources, PVC not bound, taint) |
| Running | At least 1 container running |
| Succeeded | All exited 0 (Jobs) |
| Failed | At least 1 exited non-zero |
| Unknown | kubelet unreachable |

### Error States
| Error | Root Cause | Fix |
|-------|-----------|-----|
| `ImagePullBackOff` | Wrong image/registry auth | Fix image name, add imagePullSecret |
| `CrashLoopBackOff` | App crashes on start | `kubectl logs --previous` |
| `OOMKilled` | Memory limit too low | Increase memory limit |
| `Pending` | No resources/taint/PVC | `kubectl describe pod` → Events |
| `CreateContainerConfigError` | Missing ConfigMap/Secret | Check references |

### Probes — Critical
```yaml
livenessProbe:       # Is app alive? FAIL = RESTART container
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:      # Can app serve traffic? FAIL = remove from Service endpoints (no restart)
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
  failureThreshold: 2

startupProbe:        # For slow starters (JVM) — disables liveness+readiness until passes
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30    # 30 × 10s = 5 min startup budget
  periodSeconds: 10
```
**Gotcha — if you swap them:** Liveness-as-readiness = traffic to unready pods. Readiness-as-liveness = endless restarts on slow response.

### Resources + QoS
```yaml
resources:
  requests:
    cpu: "250m"       # guaranteed allocation (scheduler uses this)
    memory: "256Mi"
  limits:
    cpu: "500m"       # CPU: throttled (never killed) when exceeded
    memory: "512Mi"   # Memory: OOMKilled when exceeded
```

| QoS Class | Condition | Eviction |
|-----------|-----------|---------|
| Guaranteed | requests == limits | Last |
| Burstable | requests < limits | Middle |
| BestEffort | No requests/limits | **First** |

### Scheduling Controls
```yaml
# Node Affinity — required (hard) or preferred (soft)
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values: ["gpu"]

  # Spread replicas across nodes
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels: {app: myapp}
        topologyKey: kubernetes.io/hostname

# Taints + Tolerations
# Add taint: kubectl taint nodes gpu-node gpu=true:NoSchedule
tolerations:
- key: "gpu"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

### StatefulSet vs Deployment
| | Deployment | StatefulSet |
|-|------------|-------------|
| Pod names | Random (pod-xyz) | Stable (pod-0, pod-1) |
| Storage | Shared/ephemeral | Per-pod PVC |
| Start order | Parallel | Sequential (0→1→2) |
| Delete order | Any | Reverse (2→1→0) |
| DNS | Single service | `pod-0.svc`, `pod-1.svc` headless |
| Use | Stateless | DBs, Kafka, Zookeeper |

---

## 9. K8s Networking + Storage + RBAC

### Service Types
| Type | Access | Use |
|------|--------|-----|
| ClusterIP (default) | Cluster-internal | Internal microservices |
| NodePort | Node IP + static port 30000-32767 | Dev/testing |
| LoadBalancer | Cloud LB | Production external |
| Headless (clusterIP: None) | Pod IPs via DNS | StatefulSets |
| ExternalName | CNAME to external hostname | External DB alias |

### Ingress vs Gateway API
| | Ingress | Gateway API |
|-|---------|-------------|
| Standard | Old, vendor annotations | **New standard (2023+)** |
| Role separation | None | GatewayClass / Gateway / HTTPRoute |
| Multi-tenancy | Poor | Built-in |

### Network Policies
```yaml
# Deny all ingress to namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
spec:
  podSelector: {}           # selects ALL pods
  policyTypes: [Ingress]
  # No ingress rules = deny all

---
# Allow only from same namespace on port 8080
spec:
  podSelector:
    matchLabels: {app: myapp}
  ingress:
  - from:
    - podSelector: {}       # any pod in same namespace
    ports:
    - port: 8080
```
**Requires CNI support:** Calico, Cilium. AWS VPC CNI does NOT support by default.

### Storage: PV + PVC + StorageClass
```
StorageClass → how PVs are provisioned (dynamically)
PVC (user) → claim storage: size + access mode
PV → actual storage (auto-created by StorageClass)

Access Modes:
  RWO (ReadWriteOnce) — single node (EBS)
  RWX (ReadWriteMany) — multiple nodes (EFS)

AWS CSI drivers:
  ebs.csi.aws.com → block (RWO)
  efs.csi.aws.com → shared (RWX)
```

### RBAC
```yaml
kind: Role                    # namespace-scoped
metadata:
  namespace: production
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]

---
kind: RoleBinding
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
```
**Test:** `kubectl auth can-i get pods --as=system:serviceaccount:production:my-app-sa`
**Rule:** One SA per app, least privilege.

---

## 10. Helm + Troubleshooting

### Helm Chart Structure
```
mychart/
├── Chart.yaml        # name, version, appVersion, dependencies
├── values.yaml       # defaults (user overrides with -f or --set)
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── _helpers.tpl  # reusable named templates
│   └── NOTES.txt     # shown after install
└── charts/           # sub-chart dependencies
```

### Key Templating
```yaml
image:
  tag: {{ .Values.image.tag | default "latest" | quote }}

{{- if .Values.ingress.enabled }}
# ingress here
{{- end }}

{{- range .Values.extraEnvVars }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
```
**`{{-`** = trim whitespace. Always use it.

### Helm Commands
```bash
helm install myapp ./chart
helm upgrade myapp ./chart --set image.tag=v2 --atomic --timeout 5m
helm rollback myapp 3          # rollback to revision 3
helm history myapp             # see all revisions
helm get values myapp --revision 3
helm uninstall myapp
```

### Deployment Strategies
| Strategy | How | Rollback |
|---------|-----|---------|
| Rolling Update (default) | Replace pods gradually | Automatic |
| Blue-Green | Two full envs, switch LB | Instant |
| Canary | 5% → 100% with gates | Instant (keep old) |

```yaml
# Zero-downtime rolling update
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0    # never take pod down before new one is up
```

### Troubleshooting Framework
```bash
# 1. Overview
kubectl get pods -A

# 2. Events (MOST USEFUL)
kubectl describe pod <name> -n <ns>    # look at Events section at bottom

# 3. App logs
kubectl logs <pod> -c <container>
kubectl logs <pod> --previous          # after CrashLoop

# 4. Live debug
kubectl exec -it <pod> -- /bin/sh
kubectl debug -it <pod> --image=busybox --target=<container>   # distroless

# 5. Cluster events
kubectl get events --sort-by='.lastTimestamp' -n <ns>
```

### Top 10 Errors Quick Fix
| Error | Check | Fix |
|-------|-------|-----|
| `ImagePullBackOff` | describe pod → Events | Fix image name, add imagePullSecret |
| `CrashLoopBackOff` | logs --previous | Fix app crash |
| `OOMKilled` | describe pod → Last State | Increase memory limit |
| `Pending` | describe pod → Events | Resources, taints, PVC |
| `Evicted` | get events | Increase disk/memory on node |
| `CreateContainerConfigError` | describe pod | Missing ConfigMap/Secret |
| PVC Pending | describe pvc | StorageClass missing |
| Service not routing | get endpoints | Selector/port mismatch |
| Node NotReady | describe node | kubelet, disk pressure |

---

## 11. Autoscaling

### HPA — Scale Pods on CPU/Memory
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: s3-lister
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```
**Requires:** metrics-server. **Scales pods only — not nodes.** Combine with Karpenter.
**K8s 1.33:** HPA tolerance now configurable (was hardcoded 10%).

### VPA — Right-size Pod Requests
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: s3-lister
  updatePolicy:
    updateMode: "Off"   # recommend only first, then move to Auto
```
**K8s 1.35 (GA):** In-place vertical scaling — no pod restart needed.
**Best practice:** Start `Off` mode, read recommendations, then `Auto`.

### KEDA — Scale on External Events
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
spec:
  scaleTargetRef:
    name: worker-deployment
  minReplicaCount: 0          # can scale to ZERO (HPA can't)
  maxReplicaCount: 50
  triggers:
  - type: aws-sqs-queue
    metadata:
      queueURL: https://sqs.us-east-1.amazonaws.com/123456789/my-queue
      queueLength: "10"       # 1 pod per 10 messages
      awsRegion: us-east-1
```
**70+ scalers:** SQS, Kafka, HTTP, Redis, Prometheus, cron, and more.

### HPA vs KEDA vs VPA vs Karpenter
| Tool | What it scales | When to use |
|------|---------------|------------|
| HPA | Pods (out/in) | User-facing REST APIs, CPU/memory |
| KEDA | Pods (+ to zero) | Background workers, queues, events |
| VPA | Pod CPU/memory requests | Right-sizing, cost optimization |
| Karpenter | Nodes | Add/remove EC2 nodes on EKS |

**Rule:** Do NOT use HPA + KEDA ScaledObject on same Deployment — they compete.

### Karpenter NodePool
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
spec:
  template:
    spec:
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]     # try spot first
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["t3.medium", "t3.large", "m5.large"]
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized   # auto bin-pack
```

### PDB — Prevent All Pods Going Down During Drain
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1       # always keep at least 1 pod
  selector:
    matchLabels: {app: s3-lister}
```
**Matters during:** node drain, rolling upgrades, Karpenter consolidation.

---

## 12. Advanced K8s

### DaemonSet — One Pod Per Node
```yaml
apiVersion: apps/v1
kind: DaemonSet
spec:
  template:
    spec:
      tolerations:
      - operator: Exists    # run on ALL nodes including control plane
        effect: NoSchedule
      containers:
      - name: alloy
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log    # read real node logs
```
**Use:** log collectors (Alloy), monitoring agents (node-exporter), CNI plugins, security agents (Falco).

### Jobs + CronJobs
```yaml
# Job — run once to completion
apiVersion: batch/v1
kind: Job
spec:
  completions: 1
  backoffLimit: 3
  template:
    spec:
      restartPolicy: Never    # MUST be Never or OnFailure
      containers:
      - command: ["python", "manage.py", "migrate"]

---
# CronJob
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 2 * * *"        # 2 AM daily
  concurrencyPolicy: Forbid     # don't run if previous still running
  jobTemplate: ...
```

### Init Containers + Multi-Container Patterns
```yaml
spec:
  initContainers:
  - name: fetch-data            # runs first, must exit 0
    image: amazon/aws-cli
    command: ["/bin/sh", "-c"]
    args: ["aws s3 ls > /html/index.html"]
    volumeMounts: [{name: html, mountPath: /html}]

  containers:
  - name: nginx                 # starts only AFTER init exits 0
    image: nginx
    volumeMounts: [{name: html, mountPath: /usr/share/nginx/html}]

  volumes:
  - name: html
    emptyDir: {}                # shared between init + main
```
**This is our s3-lister:** init container fetches S3 → writes HTML → nginx serves it.

**Sidecar vs Ambassador vs Adapter:**
- **Sidecar:** helper alongside main (fluentd, Envoy/Istio)
- **Ambassador:** proxy in front (rate limit, mTLS without app changes)
- **Adapter:** transform main's output (convert metrics format)

### CRDs + Operators
```
CRD = new resource type added to K8s API
Operator = CRD + Controller (watches CRs + takes action)

cert-manager Operator → watches Certificate CRs → calls Let's Encrypt → stores cert
Prometheus Operator  → watches ServiceMonitor CRs → updates Prometheus config
ESO                  → watches ExternalSecret CRs → syncs from AWS SM

# After installing CRDs, you can create:
kind: Certificate        (cert-manager)
kind: ServiceMonitor     (Prometheus Operator)
kind: ScaledObject       (KEDA)
kind: Application        (ArgoCD)
```

### ConfigMaps — 3 Consumption Patterns
```yaml
# 1. Single env var
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: LOG_LEVEL

# 2. All keys as env vars
envFrom:
- configMapRef:
    name: app-config

# 3. Mount as files
volumes:
- name: config
  configMap: {name: app-config}
volumeMounts:
- name: config
  mountPath: /etc/app
# Result: /etc/app/LOG_LEVEL exists as file
```
Same patterns work for Secrets.

### Resource Quotas + LimitRanges
```yaml
# ResourceQuota — limit per namespace
apiVersion: v1
kind: ResourceQuota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    pods: "50"

---
# LimitRange — default per pod/container
apiVersion: v1
kind: LimitRange
spec:
  limits:
  - type: Container
    default: {cpu: 500m, memory: 256Mi}
    defaultRequest: {cpu: 100m, memory: 128Mi}
    max: {cpu: "2", memory: 2Gi}
```
**Multi-tenancy:** namespace per team + ResourceQuota + LimitRange + RBAC + NetworkPolicy.

---

## 13. GitOps — ArgoCD

### Push vs Pull
```
Push (old): CI/CD tool → kubectl apply → cluster
  Problem: CI needs cluster creds, drift possible

Pull (GitOps): git = desired state
  ArgoCD (in cluster) → watches git → syncs diff
  Benefit: no external tool needs cluster access, git = audit trail
```

### ArgoCD Application CR
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: s3-lister
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/imsameerkhan12/devops-master-prep
    targetRevision: main
    path: app/s3-lister/chart
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true       # delete K8s resources removed from Git
      selfHeal: true    # revert manual kubectl apply changes
```

### App-of-Apps Pattern
```
root-app (Application)
  ├── traefik-app
  ├── cert-manager-app
  ├── monitoring-app
  └── s3-lister-app
```
One entry point manages everything.

### ApplicationSet — Multi-cluster/Multi-env
Auto-generates Applications from a template (same app, multiple clusters/envs).

### ArgoCD vs Flux
| | ArgoCD | Flux |
|-|--------|------|
| Market share | ~60% | ~40% |
| UI | Rich web UI | CLI-first |
| CNCF | Graduated | Graduated |
Both valid. ArgoCD = more popular + better UI. Flux = lighter + Kubernetes-native.

```bash
# Port-forward ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Login
argocd login localhost:8080 --insecure
```

---

## 14. External Secrets Operator

See Section 6 for full YAML. Quick reference:

```
Flow:
ClusterSecretStore → defines provider (AWS SM, Vault, etc.)
ExternalSecret → what to sync + target K8s Secret
ESO controller → watches → fetches → creates K8s Secret
Pod → uses K8s Secret as normal (env var or volume mount)

Auth: ESO SA uses IRSA to call AWS SM API
Refresh: every refreshInterval (default 1h)
```

**Install:**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

---

## 15. OpenTofu / IaC

> **We use OpenTofu, NOT Terraform.**
> HashiCorp changed Terraform to BSL license August 2023 — not open source.
> OpenTofu = Linux Foundation fork, MPL 2.0, drop-in replacement. Same HCL, same state format.

### Commands
```bash
tofu init       # initialize + download providers
tofu plan       # show what will change
tofu apply      # apply changes
tofu destroy    # destroy all resources
tofu validate   # validate config syntax
```

### Remote State — S3 (Modern)
```hcl
terraform {
  backend "s3" {
    bucket       = "devops-lab-tfstate"
    key          = "eks/tofu.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true    # S3 native locking — NO DynamoDB needed (OpenTofu 1.8+)
  }
}
```
**Old way (avoid):** `dynamodb_table = "terraform-lock"` — extra resource, extra cost.

### Power Commands
```bash
tofu state list                         # list all resources in state
tofu state show aws_vpc.main            # show resource details
tofu state mv aws_instance.old aws_instance.new    # rename without destroy
tofu state rm aws_instance.web          # remove from state, keep real resource
tofu import aws_instance.web i-1234abcd # import existing resource
tofu apply -replace=aws_instance.web   # force recreate
tofu plan -out=tfplan && tofu apply tfplan   # CI/CD pattern
```

### Module Structure
```
infra/
├── modules/
│   ├── vpc/          # reusable: main.tf, variables.tf, outputs.tf
│   └── eks/
└── envs/
    ├── dev/          # uses modules + dev tfvars + dev state
    ├── staging/
    └── prod/         # separate state, ideally separate AWS account
```

### Pulumi vs OpenTofu
| | OpenTofu | Pulumi |
|-|---------|--------|
| Language | HCL | TypeScript, Python, Go |
| Logic | Limited (if/count) | Full programming |
| Type safety | None | IDE + types |
| Tests | tofu test (basic) | Unit tests |
| Use | Standard infra, large module ecosystem | Complex logic, multi-cloud |

**Your articulation:** "Pulumi at TokenTide — Dgraph needed conditional logic + custom resources that HCL couldn't express cleanly. Terraform/OpenTofu at Cybage — simpler infra, team familiarity."

---

## 16. CI/CD — GitHub Actions + Azure DevOps

### GitHub Actions Anatomy
```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:       # manual
  schedule:
    - cron: '0 6 * * 1'   # Monday 6am UTC

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  deploy:
    needs: test            # depends on test
    if: github.ref == 'refs/heads/main'
```

### OIDC with AWS — Current Standard
```yaml
# Old way (BAD — long-lived keys)
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}

# OIDC way (CORRECT — no stored keys)
permissions:
  id-token: write
  contents: read

steps:
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/github-actions-role
    aws-region: us-east-1
    # GitHub issues JWT → AWS STS verifies → temp creds (15 min)
```
**5 OIDC setup steps:**
1. AWS: Create OIDC provider for `token.actions.githubusercontent.com`
2. IAM role with trust policy: `StringLike: repo:org/repo:*`
3. Attach permissions to role
4. GitHub: `permissions: id-token: write`
5. Use `configure-aws-credentials@v4` with `role-to-assume`

### Full Production Pipeline Pattern
```yaml
jobs:
  test: ...                    # run tests

  build-push:
    needs: test
    steps:
    - uses: aws-actions/configure-aws-credentials@v4
    - uses: aws-actions/amazon-ecr-login@v2
    - uses: docker/build-push-action@v5
      with:
        push: true
        tags: ${{ env.ECR_REPO }}:${{ github.sha }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy:
    needs: build-push
    environment: production    # manual approval gate
    steps:
    - run: aws eks update-kubeconfig --name ${{ env.EKS_CLUSTER }}
    - run: |
        helm upgrade --install myapp ./charts/myapp \
          --set image.tag=${{ github.sha }} \
          --atomic --timeout 5m
```

### Azure DevOps Key Concepts
- **Stages → Jobs → Steps** (hierarchical)
- **Service connections:** Cloud auth, Docker registry, GitHub
- **Variable groups:** Shared vars + Key Vault integration
- **Environments + Approvals:** Manual gate between stages
- **agent pools:** Microsoft-hosted (free), self-hosted, scale-set

### Branching Strategy
| | GitFlow | Trunk-based |
|-|---------|-------------|
| Branches | main, develop, feature/*, release/* | main + short-lived features |
| 2026 | Legacy | **Standard** |

---

## 17. Observability

### Three Pillars
| Pillar | What | When to Use |
|--------|------|------------|
| **Metrics** | Numbers over time (req/sec, p99, CPU%) | Dashboards, alerts, trends |
| **Logs** | Text events | Debugging specific incidents |
| **Traces** | Journey of one request across services | Finding which service is slow |

**Metrics say SOMETHING is wrong. Logs say WHAT. Traces say WHERE.**

### Prometheus
**Pull-based:** scrapes `GET /metrics` from pods every 15s.

### Metric Types
| Type | Behavior | Query Pattern |
|------|---------|--------------|
| Counter | Only goes up | Always use `rate()` |
| Gauge | Up and down | Use directly |
| Histogram | Distribution (for latency) | `histogram_quantile()` |
| Summary | Pre-calculated percentiles | Avoid — use Histogram |

### PromQL Cheatsheet
```promql
# Request rate (per second, 5m window)
rate(http_requests_total[5m])

# Error rate %
rate(http_requests_total{status=~"5.."}[5m])
/ rate(http_requests_total[5m]) * 100

# p99 latency from histogram
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Sum across all pods
sum by (service) (rate(http_requests_total[5m]))

# Pod memory
container_memory_working_set_bytes{namespace="default"}

# Pod restarts (last 1h)
increase(kube_pod_container_status_restarts_total[1h]) > 0

# Node CPU usage %
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# PVC almost full (> 85%)
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85
```

### kube-prometheus-stack
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin123

# Access
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80    # Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

**What's installed:**
| Component | Purpose |
|-----------|---------|
| Prometheus Operator | Watches ServiceMonitor/PrometheusRule CRDs |
| Prometheus | Scrapes + stores metrics |
| Alertmanager | Route + deduplicate alerts |
| Grafana | Dashboard UI |
| node-exporter | Node-level metrics (DaemonSet) |
| kube-state-metrics | K8s object state (pod counts, deployment status) |

### ServiceMonitor — Tell Prometheus to Scrape Your App
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    release: kube-prometheus-stack    # must match Prometheus operator selector
spec:
  selector:
    matchLabels: {app: my-app}        # matches your Service
  endpoints:
  - port: metrics                     # Service port named "metrics"
    interval: 30s
    path: /metrics
```

### PrometheusRule — Alerts as Code
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
spec:
  groups:
  - name: my-app
    rules:
    - alert: HighErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m])
        / rate(http_requests_total[5m]) > 0.01
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Error rate above 1%"
```

### Cardinality Explosion
```
Every unique label combination = 1 time series = memory in Prometheus

user_id label + 100,000 users = 1.5M series → Prometheus OOM

GOOD labels: service, method, status_code, region, env, version
BAD labels:  user_id, order_id, session_id, IP address
High-cardinality data → use LOGS, not metrics
```

### RED vs USE
| | For | R | E | D/U/S |
|-|----|---|---|-------|
| **RED** | Services (APIs) | Rate (req/s) | Errors (/s) | Duration (p99 latency) |
| **USE** | Infrastructure (nodes, DBs) | Utilization (%) | Saturation (queue depth) | Errors |

### SLI / SLO / SLA / Error Budget
```
SLI  = what you measure: "99.2% requests returned 2xx in < 200ms this week"
SLO  = internal target: "We want 99.5% of requests < 200ms"
SLA  = customer contract: "We guarantee 99.0% uptime"
Error budget = 1 - SLO = allowed bad time
  99.9% SLO → 0.1% budget → 43.8 minutes downtime/month

Burn rate alerting: "consuming error budget 10x faster than allowed → page NOW"
```

### Logging — Modern Stack (2026)

**Grafana Alloy** (replaces Promtail, deprecated EOL March 2026):
```
Old: 3 DaemonSets (Promtail + node-exporter + OTel)
New: 1 DaemonSet (Alloy handles logs + metrics + traces)

Alloy reads /var/log/pods/ → adds K8s labels → ships to Loki
```

### Loki
```logql
# All logs from app
{app="s3-lister", namespace="default"}

# Filter to ERROR only
{app="s3-lister"} |= "ERROR"

# Parse JSON + filter
{app="s3-lister"} | json | level="ERROR"

# Count errors per minute (logs → metric)
count_over_time({app="s3-lister"} |= "ERROR" [1m])
```
**Loki 3.0:** stores everything in S3 — no separate index DB.

### Pre-built Grafana Dashboards (import IDs)
| Dashboard | ID |
|-----------|----|
| K8s cluster overview | 315 |
| Node Exporter full | 1860 |
| K8s pods | 6417 |
| Traefik | 17347 |

### OpenTelemetry
```
OTel SDK (in app) → OTLP protocol → OTel Collector / Alloy
                                    ├── → Tempo (traces)
                                    ├── → Prometheus (metrics)
                                    └── → Loki (logs)

Auto-instrumentation (zero code changes):
annotations:
  instrumentation.opentelemetry.io/inject-java: "true"
```

### LGTM Stack
```
L — Loki   (logs, S3 backend, Alloy collector)
G — Grafana (visualization — one UI for everything)
T — Tempo  (distributed traces)
M — Mimir  (long-term metrics at scale)
```

### Production Debugging: API Latency Spike
```
Step 1: Confirm scope — one endpoint? all? one region?
Step 2: RED metrics — p99 spike + error rate correlation?
Step 3: Find slow trace in Tempo — which span?
Step 4: DB slow? → slow query log / EXPLAIN ANALYZE
Step 5: Pod resources — CPU throttling? GC pauses? OOMKilled?
Step 6: Correlate with recent deployments
Step 7: MITIGATE FIRST (rollback/scale up) → then root cause
```

---

## 18. cert-manager

```
Problem: TLS certs expire (Let's Encrypt = 90 days). Manual renewal = someone forgets = RED WARNING.
Solution: cert-manager automates certificate lifecycle — issue, store, auto-renew.
```

### CRDs
```
ClusterIssuer → WHERE to get certs (Let's Encrypt, Vault, self-signed) — cluster-scoped
Certificate   → "I want a cert for this domain" — fulfilled, stored as K8s Secret
CertificateRequest → auto-created per renewal (don't touch)
```

### ClusterIssuer + Certificate
```yaml
# Step 1 — ClusterIssuer (once per cluster)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: khannsameer1211@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: traefik-gateway
            namespace: traefik

---
# Step 2 — Certificate per domain
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: s3-lister-tls
  namespace: default
spec:
  secretName: s3-lister-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - s3lister.example.com
```

**ACME flow:** cert-manager → Let's Encrypt → "serve token at /.well-known/acme-challenge/" → Traefik routes to solver pod → verified → cert issued → stored as K8s Secret → auto-renews day 60.

---

## 19. Hands-On Tasks

**Start cluster:**
```bash
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
# wait ~17 min
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

**Destroy (always same day — ~$5-8/hr cost):**
```bash
gh workflow run destroy.yaml --repo imsameerkhan12/devops-master-prep
```

---

### Session A — Monitoring (Tier 1: Tasks 1→2→3→5→16)

**Task 1: kube-prometheus-stack**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.adminPassword=admin123

kubectl get pods -n monitoring     # verify everything running
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

**Task 2: Write 5 PromQL Queries** (in Prometheus UI at localhost:9090)
```promql
rate(http_requests_total[5m])
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
container_memory_working_set_bytes{namespace="default"}
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Task 3: RED Dashboard in Grafana** (4 panels)
- Panel 1: Request rate — `sum(rate(http_requests_total[5m]))` → Time series
- Panel 2: Error rate % → Time series
- Panel 3: p99 latency → Time series
- Panel 4: Pod count — `count(kube_pod_status_running{namespace="default"})` → Stat

**Task 5: ServiceMonitor for s3-lister**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: s3-lister
  namespace: default
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels: {app: s3-lister}
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
```
```bash
kubectl apply -f servicemonitor.yaml
# Verify: Prometheus UI → Status → Targets → find s3-lister
```

**Task 16: PrometheusRule — Alert for s3-lister**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: s3-lister-alerts
  namespace: default
  labels:
    release: kube-prometheus-stack
spec:
  groups:
  - name: s3-lister
    rules:
    - alert: S3ListerHighErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m])
        / rate(http_requests_total[5m]) > 0.01
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "s3-lister error rate > 1%"
```
```bash
kubectl apply -f prometheusrule.yaml
# Verify: Prometheus UI → Alerts → find S3ListerHighErrorRate
```

---

### Session B — Autoscaling (Tasks 4→6→7→10→11)

**Task 4: Grafana Alloy + Loki**
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Loki (simple scalable mode)
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1

# Alloy (replaces Promtail)
helm upgrade --install alloy grafana/alloy \
  --namespace monitoring

# Add Loki as datasource in Grafana UI → Explore → see s3-lister logs
```

**Task 6: HPA for s3-lister**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: s3-lister-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: s3-lister
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```
```bash
kubectl apply -f hpa.yaml

# Load test — stress CPU
kubectl run load --image=busybox --restart=Never -- /bin/sh -c \
  "while true; do wget -q -O- http://s3-lister.default.svc.cluster.local; done"

# Watch in another terminal
kubectl get hpa -n default -w
kubectl get pods -n default -w
```

**Task 7: KEDA + ScaledObject**
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
```
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: s3-lister-scaler
spec:
  scaleTargetRef:
    name: s3-lister
  minReplicaCount: 0
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring:9090
      metricName: http_requests_total
      threshold: "100"
      query: sum(rate(http_requests_total[2m]))
```

**Task 10: PDB for s3-lister**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: s3-lister-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels: {app: s3-lister}
```
```bash
kubectl apply -f pdb.yaml
# Test: kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# Verify: only 1 pod evicted at a time
```

**Task 11: VPA in Off mode**
```bash
# Install VPA (requires CRDs first)
kubectl apply -f https://github.com/kubernetes/autoscaler/raw/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml
kubectl apply -f https://github.com/kubernetes/autoscaler/raw/master/vertical-pod-autoscaler/deploy/vpa-rbac.yaml
```
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: s3-lister-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: s3-lister
  updatePolicy:
    updateMode: "Off"   # recommendations only — no changes applied
```
```bash
kubectl apply -f vpa.yaml
# After a few minutes:
kubectl describe vpa s3-lister-vpa     # see recommendations
```

---

### Session C — GitOps + Secrets (Tasks 8→9)

**Task 8: ArgoCD + Migrate s3-lister**
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  --set configs.params.server.insecure=true

kubectl port-forward -n argocd svc/argocd-server 8080:80
# Get initial password:
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: s3-lister
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/imsameerkhan12/devops-master-prep
    targetRevision: main
    path: app/s3-lister/chart
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Task 9: External Secrets Operator**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace
```
Then apply ClusterSecretStore + ExternalSecret (see Section 6 + 14).

---

### Session D — Policies (Tasks 12→13)

**Task 12: NetworkPolicy — isolate namespace**
```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF

# Test: exec into pod in different namespace, curl should fail
kubectl run test --image=curlimages/curl -n kube-system --restart=Never \
  -- curl http://s3-lister.default.svc.cluster.local   # should fail
```

**Task 13: ResourceQuota + LimitRange**
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: default
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    pods: "20"
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: default
spec:
  limits:
  - type: Container
    default: {cpu: 500m, memory: 256Mi}
    defaultRequest: {cpu: 100m, memory: 128Mi}
EOF

# Test: create pod without requests → it gets defaults applied
kubectl describe pod <new-pod>    # verify default limits injected
```

---

## 20. Interview Q&A Rapid Fire

**K8s Internals:**

Q: Pod is Pending — 5 debug steps?
> 1. `kubectl describe pod` → Events section
> 2. Check node resources: `kubectl describe node`
> 3. Check for taints without tolerations
> 4. Check PVC: `kubectl get pvc`
> 5. Check image pull: might become ImagePullBackOff

Q: Swap liveness and readiness — what happens?
> Liveness as readiness = traffic to unready pods → errors for users.
> Readiness as liveness = any slow response = restart loop → OOMKill spiral.

Q: StatefulSet vs Deployment — 4 differences?
> 1. Stable pod names (pod-0) vs random. 2. Per-pod PVC vs shared. 3. Ordered start/stop vs parallel. 4. Headless DNS per pod vs single Service.

Q: Why HPA needs metrics-server?
> metrics-server aggregates pod CPU/memory from kubelets. HPA polls metrics-server every 15s. Without it, `kubectl top` and HPA both fail.

Q: Service not routing traffic — what do you check?
> `kubectl get endpoints <svc>` — if empty, selector mismatch. If populated, check pod port vs service targetPort.

---

**AWS:**

Q: IRSA vs node IAM role?
> Node role = all pods share permissions = blast radius huge. IRSA = per-pod SA granularity, one pod compromised ≠ all pods. Audit trail per SA in CloudTrail.

Q: SG vs NACL — key difference?
> SG is stateful (return traffic auto-allowed), NACL is stateless (both directions explicit). SG is allow-only, NACL can deny. SG = instance level, NACL = subnet level.

Q: VPC Gateway vs Interface endpoint?
> Gateway = FREE, only S3/DynamoDB, route table entry. Interface = paid (ENI), all other AWS services, DNS-based. Both keep traffic within AWS network.

---

**Observability:**

Q: Why `rate()` instead of raw counter?
> Raw counter is meaningless alone — is 15,847 requests over 1 second or 1 year? `rate()` gives per-second rate averaged over window. Counters always need `rate()`.

Q: Cardinality explosion — what is it?
> Every unique label combination = 1 time series in Prometheus. Adding user_id to a metric with 100K users = 1.5M+ series → Prometheus OOM crash.

Q: RED vs USE?
> RED = services (Rate/Errors/Duration). USE = infrastructure (Utilization/Saturation/Errors).

Q: Error budget?
> 1 - SLO. 99.9% SLO = 43.8 min downtime/month budget. Burn rate alerting = are we consuming budget too fast?

---

**IaC:**

Q: Why OpenTofu over Terraform?
> HashiCorp changed Terraform license to BSL (Business Source License) in August 2023 — no longer open source. OpenTofu is the Linux Foundation fork, MPL 2.0, drop-in replacement with same HCL and state format.

Q: `tofu state mv` vs `tofu import`?
> `state mv` renames a resource in state (no destroy/recreate, code was renamed). `import` adds an existing real resource to state that was created outside Terraform.

Q: S3 backend `use_lockfile` vs DynamoDB?
> Old: DynamoDB table for state locking — extra resource, cost, maintenance. New (OpenTofu 1.8+ / Terraform 1.10+): S3 native locking with conditional writes. No extra resource needed.

---

**CI/CD:**

Q: OIDC vs static AWS keys in GitHub Actions?
> Static keys = long-lived, leak risk, need rotation. OIDC = GitHub issues JWT, AWS STS verifies, temp creds valid 15 min. No keys stored anywhere. Audit trail per workflow run in CloudTrail.

Q: `helm upgrade --atomic` — what does it do?
> If upgrade fails or times out, automatically rolls back to previous revision. Prevents broken partial upgrades in production.

---

**GitOps:**

Q: ArgoCD `prune` vs `selfHeal`?
> `prune`: resource removed from Git → ArgoCD deletes from K8s. `selfHeal`: someone does `kubectl apply` manually → ArgoCD reverts it back to Git state.

Q: App-of-Apps vs ApplicationSet?
> App-of-Apps: one Application managing other Applications — simple, works for fixed set. ApplicationSet: templates generate Applications dynamically — better for multi-cluster or many environments.

---

**Quick Decision Table:**
| Scenario | Answer |
|----------|--------|
| One pod per node | DaemonSet |
| Run task on schedule | CronJob |
| Scale pods on SQS queue | KEDA |
| Scale pods to zero | KEDA |
| Right-size pod resources | VPA (Off mode first) |
| Add nodes fast on EKS | Karpenter |
| Prevent all pods evicted | PDB |
| Sync secrets from AWS SM | External Secrets Operator |
| Git = source of truth | ArgoCD (GitOps) |
| TLS cert automation | cert-manager |
| Namespace resource limits | ResourceQuota + LimitRange |
| Setup before app starts | Init container |
| Helper alongside main | Sidecar |

---

## 21. Conceptual Analogies — Hindi

> These analogies are for deep understanding. English interview answers are below each one.

### TCP 3-Way Handshake — Phone Call

```
Tera browser          Google ka server
     |                      |
     |-------- SYN -------->|   "Connection chahiye"
     |<------ SYN-ACK ------|   "Ok ready hu — tu ready hai?"
     |-------- ACK -------->|   "Haan ready hu — shuru karte hain"
     |<=== Data flow ======>|   Ab actual data flow

Real life: "Bhai sun sakta hai?" → "Haan! Tu sun sakta hai?" → "Haan! Chal baat karte"
```

**Interview:** "TCP 3-way handshake establishes reliable connection. SYN (client initiates), SYN-ACK (server confirms + asks back), ACK (client confirms). Only then data flows. UDP skips this — faster, no guarantee."

---

### DNS TTL — Fridge Analogy

```
Doodh ka packet fridge mein → "Use by: 3 din"
DNS cache            → "TTL = 3600 sec (1 ghanta)"

Browser → DNS se poocha → "google.com = 142.250.x.x, TTL=3600"
          1 ghante tak cache mein, dobara DNS se nahi poochega
          TTL expire → phir DNS se poochega

Migration playbook:
  Step 1: TTL = 300 (2-3 din pehle set karo)
  Step 2: IP change karo
  Step 3: 5 min mein propagate → verify
  Step 4: TTL = 3600 wapas
```

**Interview:** "TTL defines how long resolvers cache a DNS record. Before migration I lower TTL to 5 minutes so the change propagates quickly. Once stable, I restore the long TTL to reduce DNS lookup load."

---

### TLS Handshake — Bank + Paint Mixing

```
Step 1 — ClientHello: "Main TLS 1.3 jaanta hu, ye ciphers support karta hu"
Step 2 — ServerHello + Certificate: "Ye lo mera ID card (DigiCert se)"
Step 3 — Certificate verify: CA trusted? Domain match? Expiry valid?
Step 4 — Key Exchange (Paint Mixing trick):

  Common color:  YELLOW (public)
  Tu:            BLUE   (secret)
  Server:        RED    (secret)

  Tu bhejta hai:    Yellow+Blue  = GREEN  (public mein)
  Server bhejta:    Yellow+Red   = ORANGE (public mein)

  Tu leta hai:      Orange + Blue  = BROWN 🟤 (session key)
  Server leta hai:  Green  + Red   = BROWN 🟤 (same!)

  BROWN = Session Key — kisi ko nahi pata kaise bana = Diffie-Hellman / ECDH

Step 5 — Encrypted communication with session key (AES-256)
```

**Interview:** "TLS 1.3 does the handshake in 1 RTT. Client sends supported ciphers, server sends certificate. Client verifies CA chain, expiry, domain match. Key exchange via ECDH — both sides derive the same session key without ever transmitting it. All subsequent communication is symmetrically encrypted."

---

### CIDR — Apartment Building

```
Society: "Nehru Nagar" = VPC (10.0.0.0/16)
Building A: 10.0.1.0/24  (256 IPs) — Public floors — ALB, Bastion
Building B: 10.0.3.0/24  (256 IPs) — Private floors — EKS nodes, RDS

/24 = 32 bits total, 24 bits FIXED (network), 8 bits FREE (flats)
2^8 = 256 addresses → 254 usable (first=network addr, last=broadcast)

Formula: Total IPs = 2^(32-prefix)    Usable = Total - 2

| CIDR | Usable | Think of it as |
|------|--------|----------------|
| /32  | 1      | Single flat |
| /28  | 14     | Chhoti gali |
| /24  | 254 ★  | Ek building — most common |
| /16  | 65,534 ★ | Ek VPC — AWS default |

Router: "Packet for 10.0.3.45? That's Private Building — direct bhejo!"
```

**Interview:** "CIDR groups IP addresses so routers need only the network prefix, not every individual IP. /24 gives 254 usable addresses, /16 gives ~65,500. AWS recommends /16 for VPCs so you have room for subnets across AZs."

---

### VPC — Gated Society

```
AWS = badi building (millions of servers)
VPC = tera apna gated society — baaki kisi ka traffic andar nahi

Internet Gateway = society ka main gate
NAT Gateway     = "courier boy" — andar wale bahar bhej sakte hain,
                  bahar wale seedha andar nahi aa sakte

Private subnet = andar wali building (nodes, RDS) — no IGW route
Public subnet  = road-facing building (ALB, bastion) — IGW route hai

Private EC2 SSH timeout = NOT security group — routing issue!
  Private subnet → no route to IGW → TCP never reaches instance
```

**Interview:** "Public and private subnets differ only in route table — public has 0.0.0.0/0 → IGW, private does not. SSH timeout on private EC2 is a routing issue, not a security group issue. Private subnet resources use NAT Gateway for outbound-only internet, or VPC Endpoints for AWS services."

---

### K8s Objects — Hindi Picture

```
Internet
    │
Ingress (ALB) — traffic receive karta hai bahar se
    │
Service (ClusterIP) — pods ko group karta hai, load balance karta hai
    │
    ├── Pod 1 (Nginx)
    ├── Pod 2 (Nginx)
    └── Pod 3 (Nginx)
    ↑
Deployment — pods manage karta hai (desired state = 3)

Pod    = flat  (mortal — mara toh gaya)
Deployment = HR manager ("5 log chahiye" — gaya toh naya laao)
Service = stable address — pod IP changes, Service IP stays constant
```

---

## 22. IAM Deep Dive — All 6 Types

### Basic JSON Structure
```json
{
  "Effect": "Allow",          // Allow ya Deny
  "Action": "s3:GetObject",   // Kya kar sakta hai
  "Resource": "arn:aws:s3:::my-bucket/*",  // Kis cheez pe
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

### Priority Order — Conflict mein kaun jeeta
```
1. Explicit DENY    → anywhere? BLOCKED. Period.
2. SCP              → org allow karta hai?
3. Resource Policy  → resource ne allow kiya?
4. Identity Policy  → identity ko allow hai?
5. Permissions Boundary → ceiling ke andar hai?
6. Session Policy   → session scope mein hai?

Sab pass → ACCESS GRANTED ✅   Koi ek fail → DENIED ❌
```

### Type 3 — Permissions Boundary Example
```
Role actual perms: s3:*, ec2:*, rds:*
Boundary says:     ONLY s3:*

Effective:         ONLY s3:* (intersection)

Use case: Junior devs ko IAM banana do, but boundary stops them
          from giving themselves admin — they can't exceed boundary
```

### Type 4 — SCP Example
```
Production OU pe SCP:
  Deny: cloudtrail:StopLogging, cloudtrail:DeleteTrail
  Even Account Admin cannot stop CloudTrail
  Even root user blocked by SCP deny

SCP ≠ grant permissions. SCP = maximum allowed ceiling.
```

### Interview: IAM Role vs User
```
IAM User = permanent employee — long-term access key (leak risk)
IAM Role = contractor — STS temp creds, auto-expire
           Assigned to: EC2, Lambda, EKS pods (IRSA/Pod Identity)

NEVER hardcode IAM User keys in app/EC2/EKS — always use Role
```

---

## 23. Private EKS Debug Log — Real Incidents

> Real debugging from building devops-lab cluster. Gold for interviews.

### Context
- Private EKS cluster: nodes in private subnets, no NAT Gateway
- Using VPC endpoints instead of internet

---

### Incident 1: nodeadm Timeout — Node Never Joins

**Symptom:** Node group stuck in CREATING for 40+ minutes

**Debug:**
```powershell
aws ec2 get-console-output --instance-id i-0d0adca32e3e6e342 --latest --output text
```

**Log output:**
```
[  36s] nodeadm: retrying request EC2/DescribeInstances, attempt 2
[  67s] nodeadm: retrying request EC2/DescribeInstances, attempt 3
[ 606s] nodeadm: context deadline exceeded ← 10 min timeout
[FAILED] nodeadm-co.service — EKS Nodeadm Config
```

**Root cause:** `ec2` VPC endpoint missing → nodeadm can't fetch instance metadata → bootstrap fails → node never registers

**Fix:** Create `com.amazonaws.us-east-1.ec2` VPC endpoint → terminate old node → ASG creates new one → nodeadm completes in 0.85s ✅

---

### Incident 2: CNI Not Initialized — Node Ready=False

**Symptom:** Node registered in `kubectl get nodes` but STATUS=NotReady

**Node condition:**
```
Ready: False
cni plugin not initialized — NetworkPluginNotReady
```

**Debug:**
```powershell
kubectl logs -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent
# Output: Post "https://eks-auth.us-east-1.api.aws/...": dial tcp 18.211.73.56:443: i/o timeout
```

**Chain of failure:**
```
eks-auth VPC endpoint missing
  → Pod Identity Agent can't reach eks-auth.us-east-1.api.aws (public IP, no internet)
  → aws-node pod gets no credentials
  → aws-node can't call EC2 API to manage ENIs
  → IPAM daemon doesn't start
  → CNI never initializes
  → Node stays NotReady
```

**Fix:** Create `com.amazonaws.us-east-1.eks-auth` VPC endpoint → Pod Identity Agent + aws-node restart → Node Ready ✅

---

### Incident 3: kubectl Access Denied

**Symptom:**
```
error: You must be logged in to the server (server has asked for credentials)
```

**Root cause:** Cluster created via AWS Console (root account). IAM user `sameer` not in cluster auth.

**Fix — EKS Access Entries (modern, not aws-auth ConfigMap):**
```powershell
aws eks create-access-entry --cluster-name devops-lab-eks `
  --principal-arn arn:aws:iam::271169999916:user/sameer `
  --type STANDARD

aws eks associate-access-policy --cluster-name devops-lab-eks `
  --principal-arn arn:aws:iam::271169999916:user/sameer `
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy `
  --access-scope type=cluster
```

---

### Private EKS — 7 VPC Endpoints Checklist

**Interview gold:** "Private EKS cluster needs minimum 7 endpoints. We learned each one by breaking it."

```
✅ s3        Gateway (FREE)  — ECR image layers stored in S3
✅ ec2       Interface       — nodeadm bootstrap + VPC CNI ENI management
✅ ecr.api   Interface       — image metadata
✅ ecr.dkr   Interface       — actual image pull
✅ eks       Interface       — Kubernetes API access
✅ sts       Interface       — token exchange (IRSA + internal)
✅ eks-auth  Interface       — Pod Identity Agent credentials

Miss → What breaks:
  ec2 missing    → nodeadm timeout, node never joins
  eks-auth miss  → CNI not initialized (node joins but NotReady)
  ecr.dkr miss   → ImagePullBackOff on all pods
  sts missing    → IRSA fails silently (403 from STS)
```

---

### Final Healthy Cluster State
```
NAME                           STATUS   VERSION
ip-10-0-154-163.ec2.internal   Ready    v1.33.11-eks-4136f65

NAMESPACE    NAME                           READY
kube-system  aws-node-bn2f2                 2/2   ← VPC CNI
kube-system  coredns (×2)                  1/1   ← DNS
kube-system  ebs-csi-controller (×2)        6/6   ← Storage
kube-system  ebs-csi-node                   3/3
kube-system  eks-pod-identity-agent         1/1   ← Pod Identity
kube-system  kube-proxy                     1/1
kube-system  metrics-server (×2)            1/1   ← HPA data
```

---

## 24. Production Gotcha Patterns

> Every item below is a real bug from this project. Interview ready.

### G1 — t3.medium Pod Limit: 17 Max Without Prefix Delegation

```
Formula: max_ENIs × (IPs_per_ENI - 1) + 2
t3.medium: 3 ENIs × 6 IPs → 3×5+2 = 17 max pods

System pods alone: ~16 (kube-system + cert-manager + traefik + ARC)
Runner pod slots: 17-16 = 1 only

Fix — VPC CNI Prefix Delegation:
  ENABLE_PREFIX_DELEGATION=true → each ENI gets /28 prefix (16 IPs)
  t3.medium → 110 pods max

IaC:
  vpc-cni addon configuration_values:
    env: { ENABLE_PREFIX_DELEGATION: "true", WARM_PREFIX_TARGET: "1" }
```

### G2 — ARC JIT Token: One-Time Use, Don't Retry Same EphemeralRunner

```
JIT (Just-In-Time) token = GitHub ephemeral runner registration token
                         = ONE-TIME USE ONLY

If first pod attempt fails (IP exhaustion, OOM) → same EphemeralRunner retried
→ same expired JIT token → config.sh fails silently
→ runner exits code 0 with NO logs (looks like success!)
→ ARC marks failure → creates new EphemeralRunner after 5 attempts

Debug signature: exitCode:0, startedAt == finishedAt (same second), empty logs

Fix: Ensure first pod always succeeds (fix IP exhaustion first)
     Delete stale runners: kubectl delete ephemeralrunner -n arc-runners --all
     Never manually retry — always let ARC create fresh EphemeralRunner
```

### G3 — Kubelet ECR Credential Cache: 12-Hour Poison

```
Problem: Node booted without ECR policy → kubelet cached failed/empty ECR auth token
         Policy attached later → cache still invalid for 12 HOURS
         kubectl describe pod → 403 Unauthorized from ECR

Fix (dev): Pull runner image from public registry (ghcr.io) — bypass ECR entirely
Fix (prod): Terminate node → ASG respawns → fresh kubelet cache → ECR policy applies

Lesson: Attach IAM policies BEFORE node group boots. Order matters.
```

### G4 — Node IAM Policy Loss on Node Group Recreation

```
Community EKS module manages policy attachments internally
Node group recreated (subnet change) → module's iam_role_additional_policies lost
New node group = zero IAM policies → 403 on ECR pull

Wrong fix: aws iam attach-role-policy via CLI (not idempotent, not in state)

Correct fix: Explicit aws_iam_role_policy_attachment OUTSIDE the module
  resource "aws_iam_role_policy_attachment" "node_worker" {
    role       = module.eks.node_group_role_name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  }
  # Independent resource — survives node group recreation
```

### G5 — ARC githubConfigUrl: Repo-Level for Personal Accounts

```
❌ Wrong: githubConfigUrl = "https://github.com/imsameerkhan12"  ← user-level
          ARC connects, listener shows OK, but jobs never dispatched

✅ Fix:   githubConfigUrl = "https://github.com/imsameerkhan12/devops-master-prep"

Why: GitHub runner registration is repo-scoped for personal accounts
     GitHub → Repo → Settings → Actions → Runners = empty until repo-level URL used
     Org accounts: org-level URL works. Personal: must be repo-level.
```

### G6 — GitHub App: Administration R+W Required for Runner Registration

```
Without Administration permission:
  ARC listener connects → no runners registered
  GitHub Settings → Actions → Runners → empty list

Required permissions for ARC GitHub App:
  Actions:        Read & Write    ← job queue access
  Administration: Read & Write    ← runner register/deregister ← CRITICAL
  Metadata:       Read-only       ← mandatory for all apps

After adding: re-install app (GitHub sends confirmation email) → rerun bootstrap
```

### G7 — ARC Nodes Need Public Subnet + map_public_ip_on_launch

```
Private subnet nodes → can't reach api.github.com → runner registration fails

Fix: Move EKS nodes to public subnets (nodes still private by behavior — SG controls)
     Public subnet → IGW route → internet → api.github.com ✅

Side effect: Ec2SubnetInvalidConfiguration error if:
  map_public_ip_on_launch = false (default)
  EKS nodes in public subnet = ERROR

Fix in IaC: module.vpc { map_public_ip_on_launch = true }
```

### G8 — ArgoCD Too Heavy for t3.medium

```
argocd-application-controller (StatefulSet): ~512MB RAM alone
Redis (required):                            ~100MB RAM
Total with Traefik + ARC + cert-manager:     >4GB → node OOM

Decision: Dropped ArgoCD, use push model (ARC → helm upgrade on main merge)

Production recommendation:
  ArgoCD: use on m5.large+ with proper node sizing
  Flux CD: lighter alternative, CNCF graduated, no UI overhead
```

### G9 — ECR Pull-Through Cache: ghcr.io + quay.io Need Credentials

```
Assumption: public registries → no auth needed
Reality: AWS ECR pull-through requires creds for ghcr.io AND quay.io

Error: UnsupportedUpstreamRegistryException:
       The specified upstream registry requires authentication

Solution: Pre-push from GitHub-hosted runner (has internet)
  bootstrap.yaml (ubuntu-latest) → docker pull ghcr.io/... → docker push ECR/...
  Nodes pull from ECR via VPC endpoint — never need internet

Benefit: No extra accounts/secrets, explicit version control
```

### G10 — ArgoCD Image Tag: Already Has 'v' Prefix

```
Bug: helm show chart appVersion → "v2.14.1" (already has 'v')
     Code: ARGOCD_TAG="v$(... | tr -d '"')" → "vv2.14.1"
     Error: quay.io/argoproj/argocd:vv2.14.1 — manifest unknown

Fix: ARGOCD_TAG="$(... | tr -d '"')" → "v2.14.1" ← don't add v prefix

Rule: Always echo the appVersion before using it in scripts
      cert-manager appVersion has NO 'v' → CM_TAG="v${appVersion}" is correct
      argocd appVersion HAS 'v' → just use appVersion directly
```

### G11 — Git Bash Path Mangling

```
Windows Git Bash: converts /aws → C:/Program Files/Git/aws

aws logs delete-log-group --log-group-name /aws/eks/devops-lab-eks/cluster
# Git Bash: "hey /aws looks like a Unix path → C:/Program Files/Git/aws"
# Result: "The specified log group /aws/eks/ does not exist" (wrong path sent)

Fixes:
  1. Use PowerShell instead of Git Bash for AWS CLI commands
  2. MSYS_NO_PATHCONV=1 aws ... (Git Bash env var to disable conversion)
```

### G12 — AWS Resource Description: ASCII Only

```
Error: creating Security Group: InvalidParameterValue:
  Value for GroupDescription is invalid. Character sets beyond ASCII not supported.

Cause: Em dash — (U+2014) in description string

Fix: Replace — with regular hyphen -
     "VPC endpoints - allow HTTPS from VPC CIDR"

Rule: AWS resource names + descriptions = ASCII only
      Use ASCII in code, fancy characters only in comments
```

### G13 — OpenTofu Variable Precedence Bug

```
Tried: TF_VAR_aws_profile="" env var to override dev.tfvars value
Reality: -var-file BEATS TF_VAR_* env vars

OpenTofu precedence (low → high):
  1. default values in variable block
  2. TF_VAR_* environment variables
  3. *.auto.tfvars files
  4. -var-file flags          ← dev.tfvars is here
  5. -var flags               ← highest priority

Fix: --var='aws_profile=' to override with empty string (→ null → default cred chain)
  tofu apply --var-file=dev.tfvars --var='aws_profile='
```

### G14 — Destroy Workflow OIDC Role Missing S3 State Access

```
infra-apply: static IAM creds (sameer user) → admin → S3 state OK
destroy:     OIDC (github_actions role) → tofu init → HeadObject → 403 Forbidden

Missing from github_actions role: s3:GetObject, PutObject, DeleteObject, ListBucket

Fix: Switch destroy workflow to static creds (same as infra-apply)
     Long-term: add S3 state permissions to github_actions role

Lesson: If apply/destroy use different auth → test BOTH have same resource access
```

### G15 — Log Group Already Exists (Orphaned from Previous Run)

```
Error on tofu apply: ResourceAlreadyExistsException:
  The specified log group already exists
  Log group: /aws/eks/devops-lab-eks/cluster

Cause: eksctl destroy.sh didn't clean CloudWatch log group
       tofu apply tries to create it → already exists

Fix: Manual cleanup before apply
  aws logs delete-log-group \
    --log-group-name "/aws/eks/devops-lab-eks/cluster" \
    --profile sameer --region us-east-1

Lesson: Before applying, check for orphaned resources:
  aws eks list-clusters --profile sameer
  aws logs describe-log-groups --profile sameer (search /aws/eks/)
```

---

## 25. Lab Runbook — Actual Commands

### One-Time Setup (Never Repeat)

```powershell
# IAM user for CI (static creds for infra-apply + destroy)
aws iam create-user --user-name github-actions-ci --profile sameer
aws iam attach-user-policy --user-name github-actions-ci `
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess --profile sameer
aws iam create-access-key --user-name github-actions-ci --profile sameer

# GitHub Secrets + Variables
gh secret set AWS_ACCESS_KEY_ID       --repo imsameerkhan12/devops-master-prep --body "<key>"
gh secret set AWS_SECRET_ACCESS_KEY   --repo imsameerkhan12/devops-master-prep --body "<secret>"
gh secret set DOCKER_HUB_USERNAME     --repo imsameerkhan12/devops-master-prep --body "imsameerkhan12"
gh secret set DOCKER_HUB_ACCESS_TOKEN --repo imsameerkhan12/devops-master-prep --body "<token>"
gh variable set CLUSTER_NAME  --repo imsameerkhan12/devops-master-prep --body "devops-lab-eks"
gh variable set ECR_REGISTRY  --repo imsameerkhan12/devops-master-prep --body "271169999916.dkr.ecr.us-east-1.amazonaws.com"
# AWS_ROLE_ARN → set after first infra-apply from "Print Outputs" step
```

### Create Cluster (~17 min)

```bash
# Via GitHub Actions (recommended)
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
gh run watch --repo imsameerkhan12/devops-master-prep

# Set AWS_ROLE_ARN from "Print Outputs" step (one-time)
gh variable set AWS_ROLE_ARN --repo imsameerkhan12/devops-master-prep \
  --body "arn:aws:iam::271169999916:role/devops-lab-eks-github-actions"
```

```powershell
# Local (manual) — PowerShell, run from repo root
$env:AWS_PROFILE = "sameer"
cd iac/envs/dev
tofu init
tofu --% plan -var-file=dev.tfvars -var="aws_profile=sameer"
tofu --% apply -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"
# "yes" → ~17 min

# Connect kubectl
aws eks update-kubeconfig --region us-east-1 --name devops-lab-eks --profile sameer
kubectl get nodes          # STATUS = Ready
kubectl get pods -A        # kube-system pods all Running
```

### Install Platform Tools (~5-7 min)

```bash
# Via GitHub Actions
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep

# What it installs (in order):
# 1. Pre-push cert-manager images (quay.io → ECR)
# 2. Gateway API CRDs v1.5.1
# 3. Traefik (NLB + Gateway API)
# 4. cert-manager v1.17.0
```

### Verify Everything Running

```bash
# Traefik NLB
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# cert-manager
kubectl get pods -n cert-manager

# s3-lister (after CI push)
kubectl get pods -n default
kubectl get httproute -n default

# Trigger CI manually
git commit --allow-empty -m "test CI" && git push
gh run list --repo imsameerkhan12/devops-master-prep --workflow CI
```

### Destroy (~10-12 min)

```bash
# Via GitHub Actions (recommended — handles NLB cleanup automatically)
gh workflow run destroy.yaml \
  --repo imsameerkhan12/devops-master-prep \
  --field confirm=destroy \
  --field destroy_state_bucket=false   # keep state for recreation
```

```powershell
# Manual (if workflow fails or cluster unreachable)
# MUST do Helm uninstalls before tofu destroy — order is strict!

helm uninstall s3-lister    -n default      --ignore-not-found
helm uninstall cert-manager -n cert-manager --ignore-not-found
helm uninstall traefik      -n traefik      --ignore-not-found

Start-Sleep 60   # Wait for NLB ENIs to release

# Verify NLBs gone
aws elbv2 describe-load-balancers --profile sameer --region us-east-1 `
  --query 'LoadBalancers[?Type==`network`].LoadBalancerArn'

cd iac/envs/dev
tofu --% destroy -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"

# Final verification
aws eks list-clusters --region us-east-1     # {"clusters": []}
aws ec2 describe-vpcs --profile sameer --region us-east-1 `
  --filters "Name=tag:project,Values=devops-lab" --query 'Vpcs[].VpcId'  # []

# LAST step — only when fully done (deletes state, can't recreate without re-init)
bash iac/bootstrap/teardown-state-backend.sh
```

### Recreate After Destroy

```bash
# State bucket kept (destroy_state_bucket=false) — standard workflow:
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
# wait ~17 min, then:
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

### Quick Port Forwards

```bash
# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Traefik Dashboard
kubectl port-forward -n traefik \
  $(kubectl get pods -n traefik -o name | head -1) 8080:8080
# http://localhost:8080/dashboard/
```

### Workflow Reference

| Workflow | Trigger | Runner | Auth | What |
|---|---|---|---|---|
| `infra-apply.yaml` | push `iac/**` or manual | ubuntu-latest | Static IAM creds | State bucket + tofu apply |
| `bootstrap.yaml` | manual | ubuntu-latest | OIDC | Pre-push images + Traefik + cert-manager |
| `destroy.yaml` | manual | ubuntu-latest | Static IAM creds | Helm uninstall + tofu destroy |
| `ci.yaml` | push/PR `app/s3-lister/**` | ubuntu-latest | OIDC | helm lint + helm upgrade |

### Destroy Order — Why It Matters

```
CORRECT ORDER:
  1. helm uninstall s3-lister        ← app resources
  2. helm uninstall cert-manager     ← CRDs + controller
  3. helm uninstall traefik          ← NLB DELETED HERE (cloud controller removes it)
  4. Sleep 60s                       ← NLB ENIs need ~60s to release from subnets
  5. Force-delete any NLBs          ← safety (cloud controller may lag)
  6. tofu destroy                   ← EKS, VPC, IAM, ECR, S3
  7. teardown-state-backend.sh      ← LAST — state bucket deleted, tofu unusable after

WRONG (causes DependencyViolation):
  tofu destroy BEFORE helm uninstall traefik
  → NLB ENIs still in subnets
  → VPC deletion fails: "DependencyViolation: subnet has dependencies"
```
