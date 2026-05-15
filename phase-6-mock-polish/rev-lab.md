# Lab Cheatsheet
> Hands-On Tasks · EKS Debug Log · Production Gotchas · Runbook

---

## Cluster Lifecycle

**Start cluster (~17 min):**
```bash
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
# wait ~17 min
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

**Destroy (always same day — ~$5-8/hr cost):**
```bash
gh workflow run destroy.yaml --repo imsameerkhan12/devops-master-prep \
  --field confirm=destroy --field destroy_state_bucket=false
```

---

## Session A — Monitoring

**Task 1: kube-prometheus-stack**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.adminPassword=admin123

kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

**Task 2: 5 PromQL Queries** (run in Prometheus UI at localhost:9090)
```promql
rate(http_requests_total[5m])
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
container_memory_working_set_bytes{namespace="default"}
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Task 3: RED Dashboard in Grafana** (4 panels)
- Panel 1: Request rate — `sum(rate(http_requests_total[5m]))` → Time series
- Panel 2: Error rate %
- Panel 3: p99 latency
- Panel 4: Pod count — `count(kube_pod_status_running{namespace="default"})` → Stat

**Task 4: Grafana Alloy + Loki**
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki --namespace monitoring \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1

helm upgrade --install alloy grafana/alloy --namespace monitoring
# Add Loki datasource in Grafana UI → Explore → see logs
```

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

---

## Session B — Autoscaling

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
# Load test
kubectl run load --image=busybox --restart=Never -- /bin/sh -c \
  "while true; do wget -q -O- http://s3-lister.default.svc.cluster.local; done"
kubectl get hpa -n default -w
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

**Task 10: PDB**
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

---

## Session C — GitOps + Secrets

**Task 8: ArgoCD**
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  --set configs.params.server.insecure=true

kubectl port-forward -n argocd svc/argocd-server 8080:80
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

**Task 9: External Secrets Operator**
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace
```
Then apply ClusterSecretStore + ExternalSecret (see rev-platform.md).

---

## Session D — Policies

**Task 12: NetworkPolicy**
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
```

---

## Private EKS Debug Log — Real Incidents

### Incident 1: nodeadm Timeout — Node Never Joins

**Symptom:** Node group stuck in CREATING 40+ minutes

**Debug:**
```powershell
aws ec2 get-console-output --instance-id i-0d0adca32e3e6e342 --latest --output text
```
Output: `nodeadm: context deadline exceeded` after 10 min

**Root cause:** `ec2` VPC endpoint missing → nodeadm can't fetch instance metadata

**Fix:** Create `com.amazonaws.us-east-1.ec2` endpoint → terminate old node → ASG creates new → nodeadm completes in 0.85s ✅

---

### Incident 2: CNI Not Initialized — Node NotReady

**Symptom:** Node registered but STATUS=NotReady

**Chain of failure:**
```
eks-auth VPC endpoint missing
  → Pod Identity Agent can't reach eks-auth.us-east-1.api.aws
  → aws-node gets no credentials
  → VPC CNI never initializes
  → Node stays NotReady
```

**Fix:** Create `com.amazonaws.us-east-1.eks-auth` endpoint ✅

---

### Incident 3: kubectl Access Denied

**Symptom:** `error: You must be logged in to the server`

**Root cause:** Cluster created via Console — IAM user not in cluster auth.

**Fix — EKS Access Entries (NOT aws-auth ConfigMap):**
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

## Production Gotcha Patterns

### G1 — t3.medium Pod Limit: 17 Max
```
Formula: max_ENIs × (IPs_per_ENI - 1) + 2
t3.medium: 3 ENIs × 6 IPs → 3×5+2 = 17 max pods
System pods alone: ~16 → only 1 slot for runner pods

Fix — VPC CNI Prefix Delegation:
  ENABLE_PREFIX_DELEGATION=true → t3.medium → 110 pods max
```

### G2 — ARC JIT Token: One-Time Use
```
JIT token = one-time use only
If first pod fails → retry with same expired token → silent failure
Debug signature: exitCode:0, startedAt == finishedAt, empty logs

Fix: Never manually retry — let ARC create fresh EphemeralRunner
     Delete stale: kubectl delete ephemeralrunner -n arc-runners --all
```

### G3 — Kubelet ECR Cache: 12-Hour Poison
```
Node booted without ECR policy → kubelet cached empty ECR auth
Policy attached later → cache still invalid 12 HOURS
Fix (prod): Terminate node → ASG respawns → fresh cache

Lesson: Attach IAM policies BEFORE node group boots.
```

### G4 — Node IAM Policy Lost on Node Group Recreation
```
Wrong: aws iam attach-role-policy via CLI (not in state, not idempotent)

Correct: Explicit aws_iam_role_policy_attachment OUTSIDE the module
  resource "aws_iam_role_policy_attachment" "node_worker" {
    role       = module.eks.node_group_role_name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  }
  # Independent resource — survives node group recreation
```

### G5 — ARC githubConfigUrl: Repo-Level for Personal Accounts
```
❌ Wrong: githubConfigUrl = "https://github.com/imsameerkhan12"
✅ Fix:   githubConfigUrl = "https://github.com/imsameerkhan12/devops-master-prep"

Why: Personal accounts need repo-level URL, not user-level
```

### G6 — GitHub App: Administration R+W Required
```
Required permissions for ARC GitHub App:
  Actions:        Read & Write    ← job queue access
  Administration: Read & Write    ← runner register/deregister ← CRITICAL
  Metadata:       Read-only
```

### G8 — ArgoCD Too Heavy for t3.medium
```
argocd-application-controller: ~512MB RAM
Redis (required):               ~100MB RAM
Total with Traefik + ARC + cert-manager: >4GB → node OOM

Decision: Dropped ArgoCD. Use push model (ARC → helm upgrade).
Alternative: Flux CD — lighter, CNCF graduated, no UI overhead
```

### G11 — Git Bash Path Mangling
```
Windows Git Bash converts /aws → C:/Program Files/Git/aws
Fix: Use PowerShell for AWS CLI commands
  Or: MSYS_NO_PATHCONV=1 aws ...
```

### G12 — AWS Resource Description: ASCII Only
```
Error: InvalidParameterValue — Character sets beyond ASCII not supported
Cause: Em dash — (U+2014) in description string
Fix: Replace — with regular hyphen -
```

### G14 — Destroy Workflow OIDC Missing S3 State Access
```
infra-apply: static IAM creds → admin → S3 OK
destroy:     OIDC role → tofu init → HeadObject → 403 Forbidden

Fix: Ensure destroy workflow has s3:GetObject, PutObject, DeleteObject on state bucket
Lesson: If apply/destroy use different auth → test BOTH
```

---

## Lab Runbook — Actual Commands

### Create Cluster (~17 min)
```bash
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
gh run watch --repo imsameerkhan12/devops-master-prep
```

```powershell
# Local (manual)
$env:AWS_PROFILE = "sameer"
cd iac/envs/dev
tofu init
tofu --% plan -var-file=dev.tfvars -var="aws_profile=sameer"
tofu --% apply -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"

# Connect kubectl
aws eks update-kubeconfig --region us-east-1 --name devops-lab-eks --profile sameer
kubectl get nodes
```

### Install Platform (~5-7 min)
```bash
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
# Installs: Gateway API CRDs → Traefik (NLB) → cert-manager
```

### Verify
```bash
kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get pods -n cert-manager
kubectl get pods -n default
```

### Destroy (~10-12 min)
```bash
# Via workflow (recommended)
gh workflow run destroy.yaml --repo imsameerkhan12/devops-master-prep \
  --field confirm=destroy --field destroy_state_bucket=false
```

```powershell
# Manual (if workflow fails)
helm uninstall s3-lister    -n default      --ignore-not-found
helm uninstall cert-manager -n cert-manager --ignore-not-found
helm uninstall traefik      -n traefik      --ignore-not-found

Start-Sleep 60   # Wait for NLB ENIs to release

cd iac/envs/dev
tofu --% destroy -parallelism=20 -var-file=dev.tfvars -var="aws_profile=sameer"
```

### Destroy Order — Why It Matters
```
CORRECT ORDER:
  1. helm uninstall s3-lister
  2. helm uninstall cert-manager
  3. helm uninstall traefik          ← NLB DELETED HERE
  4. Sleep 60s                       ← NLB ENIs need ~60s to release
  5. tofu destroy
  6. teardown-state-backend.sh      ← LAST

WRONG (causes DependencyViolation):
  tofu destroy BEFORE helm uninstall traefik
  → NLB ENIs still in subnets → VPC deletion fails
```

### Port Forwards
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
kubectl port-forward -n argocd svc/argocd-server 8080:443
kubectl port-forward -n traefik $(kubectl get pods -n traefik -o name | head -1) 8080:8080
```

### Workflow Reference
| Workflow | Trigger | Auth | What |
|---|---|---|---|
| `infra-apply.yaml` | push `iac/**` or manual | Static IAM creds | tofu apply |
| `bootstrap.yaml` | manual | OIDC | Traefik + cert-manager |
| `destroy.yaml` | manual | Static IAM creds | Helm uninstall + tofu destroy |
| `ci.yaml` | push `app/s3-lister/**` | OIDC | helm lint + helm upgrade |
