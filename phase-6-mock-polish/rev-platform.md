# Platform Cheatsheet
> Secrets · GitOps · OpenTofu · CI/CD · cert-manager · Observability

---

## Secrets Management

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
  - secretKey: password
    remoteRef:
      key: prod/db/password     # path in AWS Secrets Manager
```
**Result:** `db-secret` auto-created + refreshed every 1h. No secrets in Git.

```bash
# Install
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

### K8s Secrets — Critical Warning
```yaml
apiVersion: v1
kind: Secret
data:
  password: cGFzc3dvcmQxMjM=   # base64 — NOT encrypted!
```
**base64 is encoding, not encryption.** Anyone with `kubectl get secret` can decode.
**Rule:** Never put real secret values in Git. Use ESO → AWS SM.

---

## GitOps — ArgoCD

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

### ArgoCD vs Flux
| | ArgoCD | Flux |
|-|--------|------|
| Market share | ~60% | ~40% |
| UI | Rich web UI | CLI-first |
| Memory | ~600MB+ | Lighter |

**Note:** ArgoCD too heavy for t3.medium — needs m5.large+. Flux is lighter alternative.

```bash
# Port-forward ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

---

## OpenTofu / IaC

> **We use OpenTofu, NOT Terraform.**
> HashiCorp changed Terraform to BSL license August 2023 — not open source.
> OpenTofu = Linux Foundation fork, MPL 2.0, drop-in replacement.

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
    └── prod/         # separate state, ideally separate AWS account
```

### Variable Precedence (low → high)
```
1. default values in variable block
2. TF_VAR_* environment variables
3. *.auto.tfvars files
4. -var-file flags          ← dev.tfvars is here
5. -var flags               ← highest priority

Use --var='aws_profile=' to override -var-file value
```

### Pulumi vs OpenTofu
| | OpenTofu | Pulumi |
|-|---------|--------|
| Language | HCL | TypeScript, Python, Go |
| Logic | Limited (if/count) | Full programming |
| Use | Standard infra | Complex logic, multi-cloud |

---

## CI/CD — GitHub Actions + Azure DevOps

### GitHub Actions Anatomy
```yaml
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:       # manual trigger
  schedule:
    - cron: '0 6 * * 1'   # Monday 6am UTC

jobs:
  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    environment: production    # manual approval gate
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

### Branching Strategy
| | GitFlow | Trunk-based |
|-|---------|-------------|
| 2026 | Legacy | **Standard** |
| Branches | main, develop, feature/*, release/* | main + short-lived features |

### Azure DevOps Key Concepts
- **Stages → Jobs → Steps** (hierarchical)
- **Service connections:** Cloud auth, Docker registry, GitHub
- **Variable groups:** Shared vars + Key Vault integration
- **Environments + Approvals:** Manual gate between stages

---

## cert-manager

```
Problem: TLS certs expire (Let's Encrypt = 90 days). Manual renewal = someone forgets = outage.
Solution: cert-manager automates certificate lifecycle — issue, store, auto-renew.
```

### CRDs
```
ClusterIssuer → WHERE to get certs (Let's Encrypt, Vault, self-signed)
Certificate   → "I want a cert for this domain" → stored as K8s Secret
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
spec:
  secretName: s3-lister-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - s3lister.example.com
```

**ACME flow:** cert-manager → Let's Encrypt → verify domain ownership → cert issued → stored as K8s Secret → auto-renews day 60.

---

## Observability

### Three Pillars
| Pillar | What | When to Use |
|--------|------|------------|
| **Metrics** | Numbers over time (req/sec, p99, CPU%) | Dashboards, alerts, trends |
| **Logs** | Text events | Debugging specific incidents |
| **Traces** | Journey of one request across services | Finding which service is slow |

**Metrics say SOMETHING is wrong. Logs say WHAT. Traces say WHERE.**

### Prometheus Metric Types
| Type | Behavior | Query Pattern |
|------|---------|--------------|
| Counter | Only goes up | Always use `rate()` |
| Gauge | Up and down | Use directly |
| Histogram | Distribution (for latency) | `histogram_quantile()` |

### PromQL Cheatsheet
```promql
# Request rate
rate(http_requests_total[5m])

# Error rate %
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100

# p99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Pod memory
container_memory_working_set_bytes{namespace="default"}

# Node CPU usage %
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Pod restarts (last 1h)
increase(kube_pod_container_status_restarts_total[1h]) > 0
```

### kube-prometheus-stack
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin123

# Access
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

### ServiceMonitor + PrometheusRule
```yaml
# Tell Prometheus to scrape your app
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    release: kube-prometheus-stack    # must match Prometheus operator selector
spec:
  selector:
    matchLabels: {app: my-app}
  endpoints:
  - port: metrics
    interval: 30s

---
# Alert as code
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
```

### Cardinality Explosion
```
Every unique label combination = 1 time series = memory in Prometheus

user_id label + 100,000 users = 1.5M series → Prometheus OOM

GOOD labels: service, method, status_code, region, env
BAD labels:  user_id, order_id, session_id, IP address
High-cardinality data → use LOGS, not metrics
```

### RED vs USE
| | For | R | E | D/U/S |
|-|----|---|---|-------|
| **RED** | Services (APIs) | Rate (req/s) | Errors (/s) | Duration (p99 latency) |
| **USE** | Infrastructure | Utilization (%) | Saturation (queue depth) | Errors |

### SLI / SLO / SLA / Error Budget
```
SLI  = what you measure: "99.2% requests returned 2xx in < 200ms this week"
SLO  = internal target: "We want 99.5% of requests < 200ms"
SLA  = customer contract: "We guarantee 99.0% uptime"

Error budget = 1 - SLO
  99.9% SLO → 43.8 minutes downtime/month budget

Burn rate alerting: consuming budget 10x faster → page NOW
```

### Modern Logging Stack (2026)
```
Old: Promtail (EOL March 2026)
New: Grafana Alloy — 1 DaemonSet handles logs + metrics + traces

Alloy reads /var/log/pods/ → adds K8s labels → ships to Loki

LGTM Stack:
  L — Loki   (logs, S3 backend)
  G — Grafana (one UI for everything)
  T — Tempo   (distributed traces)
  M — Mimir   (long-term metrics at scale)
```

### Grafana Dashboard Import IDs
| Dashboard | ID |
|-----------|----|
| K8s cluster overview | 315 |
| Node Exporter full | 1860 |
| K8s pods | 6417 |
| Traefik | 17347 |

### Production Debugging: API Latency Spike
```
1. Confirm scope — one endpoint? all? one region?
2. RED metrics — p99 spike + error rate correlation?
3. Find slow trace in Tempo — which span?
4. DB slow? → slow query log / EXPLAIN ANALYZE
5. Pod resources — CPU throttling? OOMKilled?
6. Correlate with recent deployments
7. MITIGATE FIRST (rollback/scale up) → then root cause
```
