# Day 13: Observability — Metrics, Logs, Traces, cert-manager

---

## Three Pillars of Observability

Your app is running in production. How do you know if it is working? Three types of signals:

| Pillar | What It Is | Storage Cost | Best For |
|--------|-----------|-------------|---------|
| Metrics | Numbers over time (CPU%, req/sec, p99 latency) | Cheap — just numbers | Dashboards, alerts, trends |
| Logs | Text events — one line per thing that happened | Expensive at scale | Debugging specific incidents |
| Traces | Journey of ONE request across services | Medium | Finding which service/DB is slow |

All three together = full observability. Metrics show SOMETHING is wrong. Logs tell you WHAT. Traces show WHERE.

---

## Prometheus

### What It Is

Open-source monitoring tool. Collects numbers (metrics) from your apps, stores them with timestamps, lets you query them, triggers alerts. Industry standard for K8s.

### Pull Model — How It Collects Data

Prometheus is **pull-based**. Every 15 seconds it makes an HTTP GET to your app's `/metrics` endpoint. Your app does not push anything — it just exposes an endpoint.

```
Every 15 seconds:
Prometheus → GET http://your-app-pod-ip:8080/metrics
App responds with plain text metrics
Prometheus reads, stores with timestamp
```

What `/metrics` looks like (Prometheus text format):

```
# HELP http_requests_total Total HTTP requests received
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 1547
http_requests_total{method="POST",status="500"} 3

# HELP memory_bytes Current memory usage
# TYPE memory_bytes gauge
memory_bytes 52428800
```

Plain text. Human readable. Each line = metric name + labels in `{}` + value.

### How Prometheus Discovers Pods (Service Discovery)

Prometheus uses the K8s API to auto-discover pods. You don't hardcode IP addresses. Two ways to tell Prometheus what to scrape:

1. **Annotations** (simple): add annotations to your pod
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

2. **ServiceMonitor CRD** (recommended with Prometheus Operator — see kube-prometheus-stack section below)

---

## Metric Types — Four Kinds

### Counter — Only Goes Up
```
http_requests_total = 15,847    (total since app started)
errors_total = 23
```
Resets to 0 on app restart. Never use raw value — use `rate()` to get per-second rate.

### Gauge — Goes Up and Down
```
active_connections = 47
memory_bytes = 52428800
cpu_usage_percent = 67.3
```
Current value. Use directly — no `rate()` needed.

### Histogram — Distribution of Values
Measures how values are distributed across buckets. Used for latency, request sizes.
```
http_duration_seconds_bucket{le="0.01"} = 200    # 200 requests < 10ms
http_duration_seconds_bucket{le="0.1"}  = 1300   # 1300 requests < 100ms
http_duration_seconds_bucket{le="0.5"}  = 1540   # 1540 requests < 500ms
http_duration_seconds_bucket{le="+Inf"} = 1547   # all requests
```
Use `histogram_quantile()` to get p50/p99/p999 latency.

### Summary — Pre-calculated Percentiles
Calculated inside the app. Less flexible than Histogram — can't aggregate across pods. Avoid in new code, use Histogram instead.

---

## TSDB — How Prometheus Stores Data

TSDB = Time Series Database. Everything stored as:
```
metric_name + labels → value at timestamp

http_requests_total{method="GET",status="200"} = 1547 at 10:00:00
http_requests_total{method="GET",status="200"} = 1589 at 10:00:15
http_requests_total{method="GET",status="200"} = 1634 at 10:00:30
```

Each unique combination of metric name + labels = one **time series**. Stored on local disk. Default retention: 15 days.

---

## PromQL — Querying Prometheus

```promql
# Current value of a metric
http_requests_total

# Filter by label
http_requests_total{method="GET"}
http_requests_total{status=~"5.."}          # regex: any 5xx

# Rate — how fast is counter growing per second (over 5 min window)
rate(http_requests_total[5m])

# Error rate as percentage
rate(http_requests_total{status=~"5.."}[5m])
/ rate(http_requests_total[5m]) * 100

# p99 latency from histogram
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Sum across all pods (total req/sec for entire service)
sum by (service) (rate(http_requests_total[5m]))

# Pod memory
container_memory_working_set_bytes{namespace="default"}

# Pod restarts in last hour
increase(kube_pod_container_status_restarts_total[1h]) > 0

# Node CPU usage %
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# PVC almost full (> 85%)
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 85
```

**Why `rate()` for counters?**
Raw counter = 15,847. Meaningless — is that over 1 second or 1 year?
`rate()` = 23.4 requests/second averaged over last 5 minutes. Useful.

`increase()` = total increase over window (not per-second). Use for "how many errors in last hour?"

---

## Cardinality Explosion — Critical Concept

Every unique label combination = one time series = memory in Prometheus.

```
{service="api", method="GET",  status="200"} = 1 series  ← fine
{service="api", method="POST", status="500"} = 1 series  ← fine

Now add user_id label (100,000 users):
5 methods × 3 statuses × 100,000 users = 1,500,000 series
→ Prometheus OOM → crash
```

**Rule: Labels must be low-cardinality.** Small, finite, predictable set of values.

- GOOD: `service`, `method`, `status_code`, `region`, `env`, `version`
- BAD: `user_id`, `order_id`, `session_id`, `request_id`, `IP address`

High-cardinality info belongs in **logs**, not metrics.

---

## Alertmanager

Prometheus evaluates alert rules. When a rule fires, it sends to Alertmanager.

Alertmanager handles:
- **Deduplication** — 10 pods all alert → 1 notification not 10
- **Grouping** — related alerts bundled together
- **Routing** — DB alerts → DBA team, K8s alerts → platform team
- **Silencing** — planned maintenance window → suppress alerts for 2 hours
- **Inhibition** — cluster is down → don't alert about every individual service

Sends to: Slack, PagerDuty, OpsGenie, email, webhook.

---

## RED Method vs USE Method

Two frameworks for deciding WHAT to monitor:

### RED — for services (APIs, microservices)
- **R**ate — requests per second
- **E**rrors — errors per second
- **D**uration — p50, p99 latency

### USE — for infrastructure (nodes, databases, network)
- **U**tilization — % of capacity used (CPU 70%, disk 85%)
- **S**aturation — work piling up (queue depth, wait time)
- **E**rrors — error count (disk errors, network drops)

Apply RED to every API service. Apply USE to every node, database, load balancer.

---

## kube-prometheus-stack — Full K8s Monitoring in One Chart

One Helm chart deploys the entire stack.

### What Gets Installed

| Component | Purpose |
|-----------|---------|
| Prometheus Operator | Watches CRDs (ServiceMonitor, PrometheusRule) → auto-configures Prometheus |
| Prometheus | Scrapes + stores metrics |
| Alertmanager | Routes + deduplicates alerts |
| Grafana | Dashboard + visualization UI |
| node-exporter | Node-level: CPU, disk, memory, network (runs as DaemonSet) |
| kube-state-metrics | K8s object state: pod counts, deployment status, PVC health |

### Install

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=15d
```

### Access (Dev / Lab)

```bash
# Grafana — http://localhost:3000  admin / admin123
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus — http://localhost:9090
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Alertmanager — http://localhost:9093
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

### ServiceMonitor CRD — Tell Prometheus to Scrape Your App

Prometheus Operator watches ServiceMonitor CRDs and auto-configures Prometheus. You never edit `prometheus.yml` manually.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: default
  labels:
    release: kube-prometheus-stack    # must match Prometheus operator's selector
spec:
  selector:
    matchLabels:
      app: my-app                     # matches your Service labels
  endpoints:
  - port: metrics                     # your Service must have a port named "metrics"
    interval: 30s
    path: /metrics
```

Your app must expose `/metrics` in Prometheus format. Use client libraries:
- Go: `github.com/prometheus/client_golang`
- Python: `prometheus_client`
- Java: Micrometer

### PrometheusRule CRD — Alert Rules as Code

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
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

### Pre-built Grafana Dashboards (import by ID)

| Dashboard | ID |
|-----------|----|
| Kubernetes cluster overview | 315 |
| Node Exporter full | 1860 |
| Kubernetes pods | 6417 |
| Traefik | 17347 |

---

## Grafana

Visualization layer on top of Prometheus (and Loki, Tempo, CloudWatch). You write PromQL queries, Grafana draws graphs/tables/number panels.

### Variables — Dynamic Dashboards

```
$namespace dropdown → selected value flows into every query:
rate(http_requests_total{namespace="$namespace", service="$service"}[5m])
```

### Dashboards as Code

Export dashboard JSON → commit to Git → provision via ConfigMap. Team shares the same dashboard, version controlled.

```
grafana/provisioning/dashboards/my-dashboard.json
```

### Correlation — The Killer Feature

```
Metrics spike at 10:23 → click → "Show logs at this time" → jumps to Loki logs
Find error log → click trace ID → opens Tempo trace
See which DB call caused the spike
```

One Grafana for all three pillars: metrics (Prometheus), logs (Loki), traces (Tempo).

---

## SLI / SLO / SLA / Error Budget

```
SLI  = what you measure
       "99.2% of requests returned 2xx in < 200ms this week"

SLO  = your internal target
       "We want 99.5% of requests < 200ms"

SLA  = contract with customer
       "We guarantee 99.0% uptime or we give credits"

Error budget = 1 - SLO = allowed "bad" time
  99.9% SLO → 0.1% error budget → 43.8 minutes downtime/month allowed
```

### Burn Rate Alerting (What Senior Engineers Do)

Threshold alerting (bad): "CPU > 80%" → fires constantly for harmless spikes → alert fatigue.

SLO burn rate alerting (good): "are we consuming error budget too fast?"

```
Monthly budget = 43.8 minutes
Burned 22 minutes in 1 hour → exhausting budget in 2 hours → PAGE NOW
```

If error rate is 1% and SLO is 99.9% → consuming budget 10x faster than allowed → critical alert.

---

## Logging

### Why Centralized Logging

Without it:
- `kubectl logs` only shows current pod — deleted pod = logs gone
- Can't search across 50 pods at once
- Can't search yesterday's logs

With centralized logging: all logs in one place, searchable, retained for days/weeks.

### Where K8s Logs Live

```
App container → writes to stdout (just print to terminal, nothing else)
                        ↓
kubelet (on every node) → captures stdout → writes to file on that node's disk
                        ↓
/var/log/pods/<namespace>_<pod>_<uid>/<container>/0.log

Problem: logs only on one node, pod dies = logs gone
Solution: centralized log collector
```

### Grafana Alloy — Current Standard (2026)

**Promtail is deprecated** (EOL March 2026). Replacement is **Grafana Alloy**.

Alloy = unified observability agent. One DaemonSet collects logs + metrics + traces. Replaces Promtail (logs), and can also replace node-exporter and OTel Collector.

```
Old way — 3 DaemonSets:
  Promtail DaemonSet       → logs → Loki
  node-exporter DaemonSet  → metrics → Prometheus
  OTel Collector DaemonSet → traces → Tempo

New way — 1 DaemonSet:
  Alloy DaemonSet → logs → Loki
                  → metrics → Prometheus / Mimir
                  → traces → Tempo
```

Alloy is built on the OpenTelemetry Collector — speaks OTLP natively.

How Alloy collects logs:
```
Node's /var/log/pods/ → Alloy reads log files
→ auto-adds K8s labels (namespace, pod, container, app, node)
→ parses JSON if structured logging
→ ships to Loki
```

### Loki — Log Storage (Current Architecture 2026)

Loki indexes only **labels**, not log content. Makes it 5-10x cheaper than Elasticsearch.

**Loki 3.0 (April 2025) storage:**
- All data in object storage (S3, GCS, Azure Blob)
- TSDB index files stored alongside chunks in S3
- No separate index database to manage

**Deployment modes:**
```
Monolithic      → single pod, everything in one binary (dev/lab)
Simple Scalable → read + write + backend separated (medium production)
Microservices   → every component separate (large scale)
```

**LogQL — Querying Loki:**
```logql
# All logs from s3-lister
{app="s3-lister", namespace="default"}

# Filter to ERROR lines only
{app="s3-lister"} |= "ERROR"

# Regex filter
{app="s3-lister"} |~ "timeout|connection refused"

# Parse JSON and filter by field
{app="s3-lister"} | json | level="ERROR"

# Count errors per minute (turns logs into a metric)
count_over_time({app="s3-lister"} |= "ERROR" [1m])
```

### ELK Stack — When to Use

ELK = Elasticsearch + Logstash + Kibana (or Fluent Bit instead of Logstash)

Elasticsearch **full-text indexes** every word in every log. Fast search but:
- 5-10x more storage than Loki
- High RAM requirement
- Complex to operate

Use ELK when:
- Full-text search is required
- Compliance — years of logs, complex queries
- Security SIEM — correlate events across systems

Use Loki when:
- K8s-native, already using Grafana
- Cost matters
- Search is mostly label-based (namespace, pod, service)

### CloudWatch Logs — AWS Native

```
Fluent Bit (DaemonSet, AWS add-on) → CloudWatch Logs
Search with CloudWatch Logs Insights (SQL-like)
Cost: $0.50/GB ingestion + $0.03/GB storage/month
```

Use when: AWS-native shop, low log volume, team not familiar with Loki.

### Structured Logging — Always JSON

Bad (plain text):
```
ERROR Failed to connect to database: timeout for user 1234
```
Hard to parse, hard to search.

Good (JSON):
```json
{"ts":"2026-05-15T10:23:02Z","level":"ERROR","service":"api","event":"db_connect_failed","user_id":"1234","timeout_ms":30000}
```

Loki auto-parses JSON. You can query: `| json | user_id="1234"` or `| json | timeout_ms > 10000`.

Rule: every log line must have — timestamp, level, service name, event name, relevant IDs.

---

## OpenTelemetry (OTel)

### Why It Exists

Every vendor (Datadog, NewRelic, Jaeger) had their own SDK. Switching vendors meant rewriting all instrumentation in every app.

OTel = one vendor-neutral standard. Write instrumentation once. Change backends by updating collector config. Zero app code changes.

### Architecture

```
Your app (OTel SDK)
    ↓ OTLP protocol
OTel Collector / Grafana Alloy (DaemonSet or sidecar)
    ├── Receivers: OTLP, Jaeger, Prometheus, Loki
    ├── Processors: batch, sampling, filter, enrich
    └── Exporters → Tempo (traces) / Prometheus (metrics) / Loki (logs)
```

### Auto-Instrumentation (Zero Code Changes)

OTel Operator injects OTel agent as init container. Supported: Java, Python, Node.js, .NET, Go.

```yaml
# Add this annotation to your pod
annotations:
  instrumentation.opentelemetry.io/inject-java: "true"
# OTel Operator auto-injects agent → app emits traces with no code changes
```

### Distributed Traces — What They Look Like

```
Request ID: abc123 came in at 10:23:01.000
├── API Gateway:    10ms
├── Auth Service:   12ms
├── User Service:  450ms  ← slow
│   └── DB query:  440ms  ← root cause found
└── Response:        2ms
Total: 474ms
```

Trace context propagated via HTTP header: `traceparent: 00-abc123-span456-01` (W3C standard)

### Prometheus 3.0 — Native OTLP

Prometheus 3.0 (in kube-prometheus-stack v85+) can now receive OTLP metrics directly. No converter needed between OTel and Prometheus anymore.

---

## cert-manager — TLS Certificate Automation

### The Problem

TLS certificates expire (Let's Encrypt: every 90 days). Without automation:
- Manually renew before expiry
- Update server config
- Repeat for every domain, every cluster
- Someone forgets → cert expires → users see RED WARNING

### What cert-manager Does

K8s controller that automates certificate lifecycle:
1. You say "I want a cert for this domain"
2. cert-manager handles ACME challenge with Let's Encrypt
3. Stores issued cert as K8s Secret
4. Auto-renews 30 days before expiry
5. You do nothing after initial setup — forever

### CRDs

```
ClusterIssuer   → defines WHERE to get certs (Let's Encrypt, Vault, self-signed)
                  cluster-scoped — any namespace can use it

Issuer          → same but namespace-scoped

Certificate     → "I want a cert for app.example.com"
                  cert-manager fulfills this, stores cert as K8s Secret

CertificateRequest → auto-created per renewal cycle, you don't touch this
```

### ACME / Let's Encrypt Flow

```
1. You apply Certificate CR
2. cert-manager calls Let's Encrypt ACME API
3. Let's Encrypt: "serve this token at http://app.example.com/.well-known/acme-challenge/<token>"
4. cert-manager creates temp HTTPRoute + pod to serve the token
5. Let's Encrypt verifies → domain ownership confirmed → issues cert
6. cert-manager stores cert as K8s Secret (type: kubernetes.io/tls)
7. cert-manager watches expiry → auto-renews on day 60 (30 days before expiry)
```

DNS-01 challenge (for wildcard certs `*.example.com`): create DNS TXT record instead of HTTP token. cert-manager can auto-create in Route53, Cloudflare, etc.

### How We Use cert-manager in This Project

**Install (bootstrap.yaml):**
```bash
helm upgrade --install cert-manager jetstack/cert-manager \
  --version 1.17.0 -n cert-manager --create-namespace \
  --set crds.enabled=true \
  --set image.repository=<ECR>/quay-io/jetstack/cert-manager-controller \
  --set webhook.image.repository=<ECR>/quay-io/jetstack/cert-manager-webhook \
  --set cainjector.image.repository=<ECR>/quay-io/jetstack/cert-manager-cainjector \
  --set startupapicheck.image.repository=<ECR>/quay-io/jetstack/cert-manager-startupapicheck
```

**Why ECR for images?** quay.io (where cert-manager images live) does NOT support ECR pull-through cache. So bootstrap.yaml:
1. Pulls 4 images from quay.io/jetstack/* (runner has internet)
2. Pushes to ECR/quay-io/jetstack/*
3. Installs Helm with `--set image.repository=<ECR>/...` overrides

**Four images:**
- `cert-manager-controller` — main controller
- `cert-manager-cainjector` — injects CA certs into webhook configs
- `cert-manager-webhook` — validates cert-manager CRs
- `cert-manager-startupapicheck` — one-time job, checks API is ready

**Current state:** cert-manager installed and running in `cert-manager` namespace. No domain attached yet. To activate TLS:

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
        gatewayHTTPRoute:         # Gateway API integration with Traefik
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
  secretName: s3-lister-tls-secret    # cert stored here
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - s3lister.example.com
```

### How ACME Challenge Works With Traefik

cert-manager creates a **temporary HTTPRoute** that Traefik picks up automatically:
```
cert-manager creates:
  HTTPRoute → route /.well-known/acme-challenge/<token> → cert-manager solver pod
          ↓
Traefik sees the new HTTPRoute (watches Gateway API resources)
          ↓
Let's Encrypt makes HTTP request → Traefik routes to solver pod → token returned
          ↓
Domain verified → cert issued → cert-manager deletes temp HTTPRoute + pod
```

### Interview Answer

> "cert-manager automates TLS certificate lifecycle. We install it via Helm with images pre-pushed to ECR because quay.io doesn't support our ECR pull-through cache. cert-manager is running and ready — activating TLS just requires a ClusterIssuer pointing to Let's Encrypt and a Certificate CR per domain. cert-manager handles the ACME HTTP-01 challenge through Traefik's Gateway API integration automatically, stores the cert as a K8s Secret, and renews 30 days before expiry — zero manual work."

---

## Production Debugging: API Latency Spike — 7 Steps

```
Step 1: Confirm scope
  One endpoint? All endpoints? One region? Specific users? Since when?

Step 2: RED metrics dashboard
  Latency p99 spike — correlated with error rate increase?

Step 3: Trace a slow request
  Find trace in Tempo — which span is the bottleneck?

Step 4: Deep dive on slow span
  DB span slow? → check slow query log, EXPLAIN ANALYZE
  External API slow? → check upstream status page

Step 5: Check pod resources
  CPU throttling? rate(container_cpu_throttled_seconds_total)
  GC pauses? (JVM metrics)
  Memory pressure? OOMKilled recently?

Step 6: Correlate with deployments
  Was anything deployed in last hour? git log + deployment history

Step 7: Mitigate first, root cause second
  Rollback / scale up → restore SLO → then investigate root cause
```

---

## LGTM Stack — Full Modern Observability

```
L — Loki      (logs, S3 backend, Alloy collector)
G — Grafana   (visualization, one UI for everything)
T — Tempo     (traces, from OTel Collector / Alloy)
M — Mimir     (long-term metrics at scale, replaces single Prometheus)
```

For labs and small clusters: Prometheus is fine instead of Mimir.
For production at scale: Mimir for long-term storage + Prometheus federation.

---

## Hands-on Checklist
- [ ] kube-prometheus-stack via Helm, access Grafana at localhost:3000
- [ ] Write 5 PromQL queries: pod CPU, error rate, p99 latency, req rate, memory
- [ ] Grafana: 4-panel RED method dashboard for an app
- [ ] ServiceMonitor CR: tell Prometheus to scrape a custom app
- [ ] Loki + Alloy: deploy, view logs in Grafana Explore tab
- [ ] cert-manager: install + create ClusterIssuer (staging) + Certificate CR
- [ ] OTel collector + sample app → traces in Tempo
