# Kubernetes Cheatsheet
> EKS · Pod Lifecycle · Networking · Storage · Helm · Autoscaling · Advanced K8s

---

## EKS Deep

### Control Plane
- AWS managed: API server, etcd, scheduler, controller-manager
- Cost: **$73/month** per cluster, HA across 3 AZs built-in

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
Internet → ALB → Ingress Controller (Traefik) → ClusterIP Service → Pod
```

### Storage Comparison
| | EBS | EFS | S3 |
|-|-----|-----|----|
| Type | Block | NFS | Object |
| Access | Single AZ, 1 node | Multi-AZ, many nodes | Global (URL) |
| K8s mode | RWO | RWX | — |
| Use | OS, DB | Shared config | Artifacts, backups |

### Private EKS — 7 VPC Endpoints Required
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

## K8s Pod Lifecycle

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

### Probes
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
**Gotcha:** Liveness-as-readiness = traffic to unready pods. Readiness-as-liveness = endless restarts.

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

## K8s Networking + Storage + RBAC

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
spec:
  podSelector: {}           # selects ALL pods
  policyTypes: [Ingress]
  # No ingress rules = deny all

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

---

## Helm + Troubleshooting

### Helm Chart Structure
```
mychart/
├── Chart.yaml        # name, version, appVersion, dependencies
├── values.yaml       # defaults
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── _helpers.tpl  # reusable named templates
│   └── NOTES.txt
└── charts/           # sub-chart dependencies
```

### Helm Commands
```bash
helm install myapp ./chart
helm upgrade myapp ./chart --set image.tag=v2 --atomic --timeout 5m
helm rollback myapp 3          # rollback to revision 3
helm history myapp
helm get values myapp --revision 3
helm uninstall myapp
```

### Deployment Strategies
| Strategy | How | Rollback |
|---------|-----|---------|
| Rolling Update (default) | Replace pods gradually | Automatic |
| Blue-Green | Two full envs, switch LB | Instant |
| Canary | 5% → 100% with gates | Instant (keep old) |

### Troubleshooting Framework
```bash
# 1. Overview
kubectl get pods -A

# 2. Events (MOST USEFUL)
kubectl describe pod <name> -n <ns>    # Events section at bottom

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

## Autoscaling

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
```

### HPA vs KEDA vs VPA vs Karpenter
| Tool | What it scales | When to use |
|------|---------------|------------|
| HPA | Pods (out/in) | User-facing REST APIs, CPU/memory |
| KEDA | Pods (+ to zero) | Background workers, queues, events |
| VPA | Pod CPU/memory requests | Right-sizing, cost optimization |
| Karpenter | Nodes | Add/remove EC2 nodes on EKS |

**Rule:** Do NOT use HPA + KEDA ScaledObject on same Deployment — they compete.

### PDB — Prevent All Pods Going Down During Drain
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1
  selector:
    matchLabels: {app: s3-lister}
```
**Matters during:** node drain, rolling upgrades, Karpenter consolidation.

---

## Advanced K8s

### DaemonSet — One Pod Per Node
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

# CronJob
apiVersion: batch/v1
kind: CronJob
spec:
  schedule: "0 2 * * *"        # 2 AM daily
  concurrencyPolicy: Forbid
```

### Init Containers
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
    emptyDir: {}
```
**Our s3-lister:** init container fetches S3 → writes HTML → nginx serves it.

### CRDs + Operators
```
CRD = new resource type added to K8s API
Operator = CRD + Controller (watches CRs + takes action)

cert-manager → watches Certificate CRs → calls Let's Encrypt → stores cert
Prometheus   → watches ServiceMonitor CRs → updates Prometheus config
ESO          → watches ExternalSecret CRs → syncs from AWS SM
```

### Quick Decision Table
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
