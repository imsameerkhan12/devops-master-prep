# Day 9: K8s Networking + Storage + Security

## Service Types

| Type | Access | Use Case |
|------|--------|---------|
| ClusterIP (default) | Cluster-internal only | Internal microservices |
| NodePort | Every node IP + static port (30000-32767) | Dev/testing only |
| LoadBalancer | Cloud provider creates external LB | Production external access |
| Headless (clusterIP: None) | Returns pod IPs via DNS | StatefulSets, direct pod discovery |
| ExternalName | CNAME to external hostname | External DB/service alias in cluster |

---

## Full Traffic Flow: Internet → Pod

```
Internet
  → Route53 DNS → ELB/ALB IP
  → AWS ALB (L7, terminates TLS)
  → K8s Service (LoadBalancer type, port 443→80)
  → kube-proxy iptables rules
  → Pod IP (VPC CNI = real VPC IP)
  → Container port 8080
```

For Ingress:
```
Internet → ALB → Ingress Controller (NGINX/ALB Ingress) → ClusterIP Service → Pod
```

---

## Ingress vs Gateway API

| | Ingress | Gateway API |
|-|---------|-------------|
| Standard | Old, vendor-specific annotations | **New standard (2023+)** |
| Role separation | None | GatewayClass (infra) / Gateway / HTTPRoute (dev) |
| Multi-tenancy | Poor | Built-in |
| Status | Stable | GA in K8s 1.28+ |

**2025-26 interviews:** Gateway API is trending. Know the role separation.

### NGINX Ingress Key Annotations
```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /
  nginx.ingress.kubernetes.io/backend-protocol: HTTPS
  nginx.ingress.kubernetes.io/rate-limit: "100"
  nginx.ingress.kubernetes.io/enable-cors: "true"
```

---

## Network Policies

**Default:** All pods can talk to all pods in all namespaces. Wide open.

**Once a NetworkPolicy selects a pod:** Only explicitly allowed traffic passes.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}          # selects ALL pods in namespace
  policyTypes:
  - Ingress
  # No ingress rules = deny all ingress

---
# Allow only from same namespace + port 8080
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
spec:
  podSelector:
    matchLabels:
      app: myapp
  ingress:
  - from:
    - podSelector: {}      # any pod in same namespace
    ports:
    - port: 8080
```

**Requires CNI support:** Calico, Cilium (AWS VPC CNI does NOT support by default).  
**Visual tool:** editor.networkpolicy.io

---

## Storage: PV + PVC + StorageClass

```
StorageClass → defines how PVs are dynamically provisioned
PVC (user) → claims storage with size + access mode
PV → actual storage (auto-created by StorageClass)

Access Modes:
- ReadWriteOnce (RWO) — single node read/write (EBS)
- ReadOnlyMany (ROX) — multiple nodes read-only
- ReadWriteMany (RWX) — multiple nodes read/write (EFS)

Reclaim Policy:
- Retain — PV persists after PVC deleted, manual cleanup
- Delete — PV deleted with PVC (default for cloud StorageClasses)
```

**AWS CSI drivers:**
- `ebs.csi.aws.com` → block storage (RWO)
- `efs.csi.aws.com` → shared storage (RWX)

---

## RBAC Deep

```yaml
# Role (namespace-scoped)
kind: Role
metadata:
  namespace: production
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]

---
# RoleBinding
kind: RoleBinding
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: production
roleRef:
  kind: Role
  name: pod-reader

---
# ClusterRole (cluster-wide) + ClusterRoleBinding for cluster-wide access
# OR: ClusterRole + RoleBinding for namespace-scoped access to cluster-wide resources
```

**Best practice:** One ServiceAccount per app. Least privilege. Audit with `kubectl auth can-i`.

```bash
kubectl auth can-i get pods --as=system:serviceaccount:production:my-app-sa
```

---

## Service Mesh Concept

**What:** Sidecar proxy (Envoy) injected per pod handles all network traffic.

**Features:**
- mTLS automatic between services
- Traffic shaping (canary, circuit breaking)
- Observability (distributed traces, metrics)
- Retries + timeouts without code changes

| | Istio | Linkerd |
|-|-------|---------|
| Complexity | High (many CRDs) | Low (simpler) |
| Performance | More overhead | Lighter (Rust proxy) |
| Features | Rich | Core features only |

**Trade-off:** Resource overhead (Envoy sidecar = ~50MB RAM per pod) vs features.

---

## Hands-on Checklist
- [ ] NGINX Ingress on Minikube: path-based + host-based routing for 2 services
- [ ] NetworkPolicy: namespace isolation, test with `curl` from different namespace
- [ ] ServiceAccount + Role limited permissions, test with `kubectl --as`
- [ ] Draw: Internet → Pod full flow diagram
