# Kubernetes Advanced Concepts

Topics not covered in Day 8-10: DaemonSets, Jobs, Autoscaling, PDB, ConfigMaps/Secrets deep, Init containers, CRDs, GitOps, External Secrets, Karpenter, Resource Quotas.

---

## DaemonSets

**Problem:** You want exactly one pod running on every node. A Deployment with `replicas=3` doesn't guarantee one per node — K8s might put all 3 on the same node.

**Solution:** DaemonSet — K8s automatically runs one pod per node. New node joins → pod auto-created. Node leaves → pod cleaned up.

**Real use cases:**
- Log collectors (Grafana Alloy) — needs to read log files from every node's disk
- Monitoring agents (node-exporter) — CPU/disk/memory from every node
- CNI plugins (Calico, Cilium) — networking must exist on every node
- Security agents (Falco) — introspect every node for threats

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: alloy
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: alloy
  template:
    metadata:
      labels:
        app: alloy
    spec:
      hostNetwork: true             # use node's network namespace
      tolerations:
      - operator: Exists            # run on ALL nodes including control plane
        effect: NoSchedule
      containers:
      - name: alloy
        image: grafana/alloy:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log            # mount node's actual log directory
```

**Interview gotcha:** "How do you run a monitoring agent on every node?" → DaemonSet. Not Deployment with replicas=node_count (fragile — nodes can change, K8s might collocate pods).

---

## Jobs + CronJobs

### Job — Run Once to Completion

Run a pod until it succeeds. Retry on failure. Stop when done.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
spec:
  completions: 1          # must succeed this many times total
  parallelism: 1          # run this many pods at once
  backoffLimit: 3         # retry 3 times before marking Failed
  template:
    spec:
      restartPolicy: Never    # MUST be Never or OnFailure — never Always
      containers:
      - name: migrate
        image: myapp:v2
        command: ["python", "manage.py", "migrate"]
```

Use for: DB migrations, batch processing, one-off scripts, data exports.

**Helm pre-upgrade hook pattern:** run Job before new app version deploys:
```yaml
annotations:
  "helm.sh/hook": pre-upgrade
  "helm.sh/hook-weight": "-5"
  "helm.sh/hook-delete-policy": before-hook-creation
```

### CronJob — Scheduled Job

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup
spec:
  schedule: "0 2 * * *"        # 2 AM every day (standard cron syntax)
  concurrencyPolicy: Forbid     # don't run if previous still running
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: cleanup
            image: myapp
            command: ["python", "cleanup.py"]
```

`concurrencyPolicy`:
- `Allow` — multiple jobs can run simultaneously
- `Forbid` — skip new job if previous still running
- `Replace` — cancel previous, start new

---

## Autoscaling

### HPA — Horizontal Pod Autoscaler

Scale pods out/in based on CPU, memory, or custom metrics.

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
        averageUtilization: 70    # scale up when avg CPU > 70%
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Requires:** `metrics-server` installed (we have it as EKS add-on).

**K8s 1.33 update:** HPA tolerance is now configurable. Old hardcoded 10% tolerance (wouldn't act until metric was 10% above/below target) can now be tuned per HPA.

**Critical:** HPA scales pods, NOT nodes. If nodes are full, new pods stay Pending. Combine with Karpenter for node autoscaling.

**Do NOT use HPA and KEDA ScaledObject on the same Deployment** — they compete and cause unstable scaling.

### VPA — Vertical Pod Autoscaler

Adjusts CPU/memory requests on pods — right-sizes them based on actual usage.

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
    updateMode: "Auto"          # or "Off" (recommend only) or "Initial"
```

**Modes:**
- `Off` — only generate recommendations, apply nothing (safest to start)
- `Initial` — apply recommendations only at pod creation
- `Auto` — apply in-place when possible, recreate if not

**K8s 1.35 update (GA):** In-place pod vertical scaling. VPA can now resize CPU/memory on a running pod **without restarting it**. The main historical downside (pod disruption) is gone.

VPA `InPlaceOrRecreate` mode (Beta K8s 1.35): tries in-place first, falls back to recreate if needed.

**Best practice:** Run in `Off` mode first, review recommendations, then enable `Auto`.

**Limit:** Max 1,000 pods per VPA object.

### KEDA — Kubernetes Event-Driven Autoscaling

Scale pods based on external event sources — SQS queue depth, Kafka consumer lag, HTTP request rate, Redis list length, cron schedule, and 70+ more.

Can scale **to zero** (HPA minimum is 1).

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: worker-scaler
spec:
  scaleTargetRef:
    name: worker-deployment
  minReplicaCount: 0          # scale to zero when queue empty
  maxReplicaCount: 50
  triggers:
  - type: aws-sqs-queue
    metadata:
      queueURL: https://sqs.us-east-1.amazonaws.com/123456789/my-queue
      queueLength: "10"       # 1 pod per 10 messages in queue
      awsRegion: us-east-1
    authenticationRef:
      name: aws-auth          # reference TriggerAuthentication for credentials
```

**TriggerAuthentication** (v2.15+) — explicit auth for external services:
```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: aws-auth
spec:
  podIdentity:
    provider: aws    # uses EKS Pod Identity for AWS access
```

**KEDA vs HPA — when to use which:**

| | HPA | KEDA |
|-|-----|------|
| Best for | User-facing REST APIs, gradual CPU load | Background workers, queues, event-driven |
| Scale to zero | No (min 1) | Yes |
| Metrics source | CPU, memory | 70+ external sources |
| Reaction time | Polls metrics API (15-30s lag) | Event-driven (immediate) |

**Production pattern:** Both together — HPA for frontend APIs, KEDA for backend workers.

### Cluster Autoscaler — Node Scaling (Old Way)

Watches for Pending pods → asks cloud provider to add a node to a node group.

Problems:
- Slow: 3-5 minutes for new node
- Node groups: you pre-define instance types per group, managing many groups = complexity
- Poor bin-packing: doesn't optimize node usage

Still valid for non-EKS or multi-cloud setups.

### Karpenter — Node Scaling (Current Standard on EKS)

Karpenter looks at what pending pods need and provisions exactly the right node — any instance type, any AZ, spot or on-demand.

**Node ready in < 60 seconds** vs 3-5 minutes for Cluster Autoscaler.

```yaml
# NodePool — what types of nodes Karpenter can provision
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot", "on-demand"]      # try spot first
      - key: node.kubernetes.io/instance-type
        operator: In
        values: ["t3.medium", "t3.large", "t3.xlarge", "m5.large"]
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized   # auto bin-pack + remove empty nodes

---
# EC2NodeClass — AWS-specific config
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: karpenter-node-role
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: devops-lab-eks
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: devops-lab-eks
```

**Consolidation:** Karpenter watches for underutilized nodes. If pods can be bin-packed onto fewer nodes, it moves pods and terminates empty nodes. Automatic cost savings.

**Status (May 2026):** v1.5, production-grade on EKS. Azure has managed version (Node Auto Provisioning). GCP partial support.

**Full autoscaling stack for production EKS:**
```
HPA      → scale pods on CPU/memory (user-facing services)
KEDA     → scale pods on events (background workers, scale to zero)
VPA      → right-size pod requests (run in Off/recommend mode)
Karpenter → add/remove nodes automatically (< 60s, spot-aware)
```

---

## Pod Disruption Budgets (PDB)

**Problem:** During node drain (rolling upgrade, cluster autoscaler scale-down), K8s might evict too many pods at once → downtime.

**PDB:** "During voluntary disruption, always keep at least N pods running."

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: s3-lister-pdb
spec:
  minAvailable: 1          # always keep at least 1 pod running
  # OR: maxUnavailable: 1  # allow at most 1 pod down at a time
  selector:
    matchLabels:
      app: s3-lister
```

With 2 replicas + `minAvailable: 1` → node drain only evicts 1 pod at a time. Never takes both down.

**Matters during:** node group upgrades, `kubectl drain`, Karpenter consolidation, cluster autoscaler scale-down.

**Interview tip:** Always create PDB for any production workload with > 1 replica.

---

## ConfigMaps + Secrets — Deep Dive

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "info"
  DB_HOST: "postgres.default.svc.cluster.local"
  config.yaml: |              # can store whole file content
    timeout: 30s
    retries: 3
    upstream: http://api.internal
```

### Three Ways to Consume

```yaml
# 1 — Single env var
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: LOG_LEVEL

# 2 — All keys as env vars (bulk inject)
envFrom:
- configMapRef:
    name: app-config

# 3 — Mount as file in pod
volumes:
- name: config
  configMap:
    name: app-config
volumeMounts:
- name: config
  mountPath: /etc/app
# Result: /etc/app/LOG_LEVEL, /etc/app/config.yaml exist as files
```

Exactly the same pattern works for Secrets — just change `configMapKeyRef` → `secretKeyRef`, `configMapRef` → `secretRef`.

### Secrets — What You Must Know

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: cGFzc3dvcmQxMjM=    # base64 encoded — NOT encrypted
```

**Critical:** K8s Secrets are **base64 encoded, not encrypted**. Anyone with `kubectl get secret` access can decode them. base64 is not security — it's just encoding.

**For real security:** Never store actual secret values in Git. Use External Secrets Operator to sync from AWS Secrets Manager / HashiCorp Vault / Azure Key Vault.

**Secret types:**
- `Opaque` — generic, any key-value data
- `kubernetes.io/tls` — TLS cert + key (used by cert-manager, Ingress, Gateway)
- `kubernetes.io/dockerconfigjson` — registry credentials (imagePullSecret)

---

## Init Containers + Multi-Container Patterns

### Init Containers

Run to completion **before** main containers start. If init container fails → pod stays in `Init:Error` state. Main container never starts.

```yaml
spec:
  initContainers:
  - name: s3-fetch              # runs first, must exit 0
    image: amazon/aws-cli
    command: ["/bin/sh", "-c"]
    args:
    - |
      aws s3 ls --region us-east-1 | awk '{print "<li>"$3"</li>"}' > /html/index.html
    volumeMounts:
    - name: html
      mountPath: /html

  containers:
  - name: nginx                 # starts only AFTER s3-fetch exits 0
    image: nginx
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html

  volumes:
  - name: html
    emptyDir: {}                # shared between init + main containers
```

This is exactly our s3-lister app: init container fetches S3 bucket list → writes HTML → nginx serves it.

**Use cases:**
- Wait for dependency to be ready (`until nc -z db 5432; do sleep 2; done`)
- Fetch secrets or config before app starts
- DB migration before new app version starts
- Generate/transform files main container needs

### Multi-Container Patterns

**Sidecar** — helper runs alongside main, same lifecycle:
```
nginx (main) + fluentd (sidecar) → fluentd tails nginx logs, ships to Loki
App (main) + Envoy (sidecar) → service mesh proxy (Istio/Linkerd)
```

**Ambassador** — proxy in front of main, handles network concerns:
```
App → Ambassador (localhost) → routes to different backends
Use: rate limiting, mTLS, circuit breaking without app code changes
```

**Adapter** — transforms main's output format:
```
App exports metrics in custom format → Adapter converts to Prometheus format
App writes logs in format X → Adapter converts to JSON for Loki
```

**Init** — setup before main starts (covered above, our s3-lister uses this)

---

## CRDs + Operators Pattern

### CRD — Extend the K8s API

K8s built-in resources: Pod, Deployment, Service, ConfigMap. CRD adds new resource types:

```yaml
# After cert-manager installs its CRDs, you can create:
apiVersion: cert-manager.io/v1
kind: Certificate           # ← custom resource, K8s didn't know this before

# After Prometheus Operator installs its CRDs:
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor        # ← custom resource

# After KEDA installs its CRDs:
apiVersion: keda.sh/v1alpha1
kind: ScaledObject           # ← custom resource
```

### Operator = CRD + Controller

A controller watches for CRs and takes action to reach desired state. This is the Operator pattern — encoding Day-2 operational knowledge into code.

```
cert-manager Operator:
  Watches Certificate CRs
  → calls Let's Encrypt ACME API
  → stores cert as K8s Secret
  → renews before expiry

Prometheus Operator:
  Watches ServiceMonitor CRs
  → generates Prometheus scrape config
  → reloads Prometheus (no restart needed)

External Secrets Operator:
  Watches ExternalSecret CRs
  → fetches secret from AWS Secrets Manager
  → creates/updates K8s Secret
  → refreshes on interval
```

**Why Operators exist:** Stateful apps (Postgres, Kafka, Elasticsearch) need complex operational tasks — backup, upgrade, scaling, failover. Operators encode this knowledge. Instead of running `pg_basebackup` manually, you create a `PostgresBackup` CR.

**CNCF Operator SDK:** framework for building operators (Go, Ansible, Helm-based).

---

## GitOps — ArgoCD

### Push Model vs Pull Model

**Traditional CI/CD (push):**
```
Code push → GitHub Actions → kubectl apply (CI pushes to cluster)
Problem: CI tool needs cluster credentials, drift possible if someone applies manually
```

**GitOps (pull):**
```
Code push → git repo updated (desired state)
ArgoCD (runs in cluster) → watches git → compares desired vs actual → syncs diff
Problem: none — cluster always matches git, no external tool needs cluster access
```

### ArgoCD Core Concepts

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
    path: app/s3-lister/chart     # Helm chart path in Git
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true       # delete resources removed from Git
      selfHeal: true    # revert manual kubectl apply changes
```

**prune:** if you delete a file from Git → ArgoCD deletes the K8s resource.
**selfHeal:** if someone does `kubectl apply` manually → ArgoCD reverts it.

### App-of-Apps Pattern

One ArgoCD Application that manages other Applications — single entry point:
```
root-app (Application) → manages:
  ├── traefik-app (Application)
  ├── cert-manager-app (Application)
  ├── monitoring-app (Application)
  └── s3-lister-app (Application)
```

### ApplicationSet — Modern Alternative for Dynamic Scenarios

Auto-generates Applications from a template. Best for:
- Same app deployed to multiple clusters
- Same app deployed to multiple environments (dev/staging/prod)
- Apps auto-discovered from Git directory

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook
spec:
  generators:
  - list:
      elements:
      - cluster: dev
        url: https://dev-cluster
      - cluster: prod
        url: https://prod-cluster
  template:
    spec:
      source:
        path: apps/guestbook
      destination:
        server: "{{url}}"
        namespace: guestbook-{{cluster}}
```

**Interview:** App-of-Apps for simpler setups. ApplicationSet for multi-cluster or many environments.

### ArgoCD vs Flux (2026)

| | ArgoCD | Flux |
|-|--------|------|
| Market share | ~60% | ~40% (growing fast) |
| UI | Rich web UI | CLI-first, minimal UI |
| Multi-tenancy | AppProject isolation | Namespace-based |
| GitOps model | Pull (same) | Pull (same) |
| CNCF status | Graduated | Graduated |

Both are valid. ArgoCD more popular, better UI. Flux more Kubernetes-native, lighter weight. Choice is team preference.

---

## External Secrets Operator (ESO)

**Problem:** K8s Secrets are base64 (not encrypted). You can't put real secrets in Git. But your app needs them in the cluster.

**Solution:** ESO syncs from external secret managers (AWS Secrets Manager, HashiCorp Vault, Azure Key Vault, GCP Secret Manager) into K8s Secrets automatically.

```yaml
# ClusterSecretStore — defines WHERE secrets come from
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa    # uses Pod Identity for AWS access

---
# ExternalSecret — defines WHAT to sync
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-password
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-secret               # creates this K8s Secret
    creationPolicy: Owner
  data:
  - secretKey: password           # key in K8s Secret
    remoteRef:
      key: prod/db/password       # path in AWS Secrets Manager
```

**Result:** `db-secret` K8s Secret auto-created and refreshed every hour from AWS SM. App uses it as normal K8s Secret. Actual secret value never in Git.

**In our project:** Docker Hub credentials in AWS Secrets Manager (`ecr-pullthroughcache/docker-hub`). ESO would be the next step to sync app-level secrets without manual `kubectl create secret`.

**ESO v2.4.1 (current May 2026):** same architecture, only latest minor version officially supported.

---

## Resource Quotas + LimitRanges

### ResourceQuota — Limit Per Namespace

Prevent one team's namespace from consuming all cluster resources:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"          # total CPU requests in namespace
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"                  # max pods in namespace
    count/deployments.apps: "10"
```

### LimitRange — Default Per Pod/Container

If pod doesn't specify requests/limits, apply defaults. Prevents pods without any resource spec:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-a
spec:
  limits:
  - type: Container
    default:                    # applied if no limits specified
      cpu: 500m
      memory: 256Mi
    defaultRequest:             # applied if no requests specified
      cpu: 100m
      memory: 128Mi
    max:                        # hard ceiling per container
      cpu: "2"
      memory: 2Gi
```

**Multi-tenancy pattern:**
```
cluster → namespaces per team
each namespace → ResourceQuota (limit total) + LimitRange (default per pod)
RBAC → each team can only access their namespace
NetworkPolicy → isolate namespace traffic
```

---

## Quick Reference — When to Use What

| Scenario | Tool |
|----------|------|
| Run exactly one pod per node | DaemonSet |
| Run a task once to completion | Job |
| Run a task on a schedule | CronJob |
| Scale pods on CPU/memory | HPA |
| Scale pods on queue depth / events | KEDA |
| Scale pods to zero | KEDA |
| Right-size pod CPU/memory requests | VPA (Off mode → Auto) |
| Add/remove nodes automatically (EKS) | Karpenter |
| Add/remove nodes (non-EKS / multi-cloud) | Cluster Autoscaler |
| Prevent all pods going down during drain | PDB |
| Non-sensitive config (URLs, log levels) | ConfigMap |
| Sensitive data (passwords, tokens) | Secret + ESO from AWS SM |
| Setup before main container starts | Init container |
| Helper alongside main container | Sidecar |
| Git as source of truth for K8s state | ArgoCD (GitOps) |
| Sync secrets from AWS SM → K8s | External Secrets Operator |
| Limit namespace resource usage | ResourceQuota + LimitRange |
