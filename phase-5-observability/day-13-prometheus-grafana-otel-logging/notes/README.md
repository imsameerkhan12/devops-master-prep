# Day 13: Prometheus, Grafana, OTel, Logging

## Three Pillars of Observability

| Pillar | What | Storage Cost | Best For |
|--------|------|-------------|---------|
| Metrics | Numbers over time (CPU%, req/sec, p99) | Cheap (aggregated) | Dashboards, alerts, trends |
| Logs | Discrete events with context | Expensive at scale | Debugging, audit, error details |
| Traces | Request journey across services | Medium | Microservices latency, dependency mapping |

---

## Prometheus Architecture

```
App pods (/metrics endpoint)
  ↑ pull (scrape every 15s)
Prometheus Server
  ├── TSDB (on-disk, 15-day default retention)
  ├── Alertmanager → PagerDuty / Slack
  └── PromQL API
        ↓
Grafana (dashboards)
```

**Service Discovery:** Prometheus auto-discovers K8s pods/services via K8s API.  
**Push Gateway:** For short-lived jobs (CronJob) that can't be scraped — push before exiting.

---

## PromQL Basics

### Metric Types
```
Counter: always increases (reset on restart) → use rate() or increase()
Gauge: goes up and down → use directly
Histogram: samples in buckets → use histogram_quantile()
```

### Common Queries
```promql
# Request rate per second (5-min window)
rate(http_requests_total[5m])

# Error rate per service
sum by (service) (rate(http_errors_total[5m]))

# p99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Pod CPU usage
sum by (pod) (rate(container_cpu_usage_seconds_total[5m]))

# Memory usage
container_memory_working_set_bytes{namespace="production"}

# Top 10 highest cardinality metrics
topk(10, count by (__name__)({__name__=~".+"}))
```

---

## Cardinality Explosion — CRITICAL

**What:** Each unique label combination = 1 time series.

```
labels: {method, status, path}
5 methods × 10 statuses × 100 paths = 5,000 series ← OK

Add: user_id (10,000 users)
= 50,000,000 series → Prometheus OOM → DB crash
```

**Rule:** Never use high-cardinality values as labels:
- BAD: `user_id`, `session_id`, `request_id`, `IP address`
- OK: `service`, `method`, `status_code`, `region`

Put high-cardinality info in **logs** instead.

---

## RED Method vs USE Method

### RED (for services / microservices)
- **R**ate — requests per second
- **E**rrors — errors per second
- **D**uration — p50, p99 latency

### USE (for infrastructure / resources)
- **U**tilization — % busy (CPU%, disk%)
- **S**aturation — queue depth, wait time
- **E**rrors — error count

**When:** RED for app services. USE for nodes, databases, network devices.

---

## Grafana

### Data Sources
- Prometheus (metrics), Loki (logs), Tempo (traces), CloudWatch, Elasticsearch

### Variables (Dropdowns)
```
$namespace, $service, $environment → parameterize queries
rate(http_requests_total{namespace="$namespace", service="$service"}[5m])
```

### Dashboards as Code
```bash
# Export dashboard JSON, commit to Git
# Import via API or provisioning
grafana/provisioning/dashboards/my-dashboard.json
```

### Alerting (Unified, v8+)
```
Alert rule → evaluates PromQL → sends to Contact Points
Contact Points: Slack, PagerDuty, Email, OpsGenie
Notification policies: routing rules based on labels
```

---

## Logging Stack Options

| | Loki | ELK | CloudWatch Logs |
|-|------|-----|-----------------|
| Indexing | Labels only (cheap) | Full-text (expensive) | None (search by filter) |
| Cost | Low | High | $0.50/GB ingestion |
| Query | LogQL (PromQL-like) | Lucene/KQL | CWL Insights |
| Best for | K8s, cost-conscious | Full-text search, complex queries | AWS-native, low volume |
| Integration | Native Grafana | Kibana | AWS Console |

### Loki Stack (kube-prometheus-stack includes it)
```bash
helm install loki grafana/loki-stack \
  --set grafana.enabled=false \
  --set promtail.enabled=true
```

### Structured Logging (Always Use JSON)
```json
{"ts":"2026-05-07T10:00:00Z","level":"ERROR","service":"auth","user_id":"1234","event":"login_failed","ip":"1.2.3.4","latency_ms":45}
```

---

## OpenTelemetry (OTel) — Modern Standard

**Why:** Vendor-neutral. Same instrumented code → ship to any backend.

```
SDK (in app) → OTel Collector → Exporters → Backend
                    ↑
         Receivers (OTLP, Jaeger, Prometheus)
         Processors (batch, sampling, filter)
         Exporters (Tempo, Datadog, Jaeger, NewRelic)
```

### Auto-instrumentation (no code changes)
```yaml
# K8s: inject OTel agent as init container via OTel Operator
annotations:
  instrumentation.opentelemetry.io/inject-java: "true"
```

### Distributed Tracing
```
TraceID: abc123 (one per request, propagated via HTTP header)
├── Span: API Gateway (10ms)
├── Span: Auth Service (5ms)
├── Span: User Service (200ms)
│   └── Span: DB query (180ms) ← SLOW SPAN
└── Span: Response (2ms)
```

W3C TraceContext header: `traceparent: 00-abc123-span456-01`

---

## Production Debugging: API Latency Spike — 7 Steps

```
Step 1: Confirm scope
  - One endpoint? All endpoints? Specific region? Specific users?

Step 2: Check RED metrics dashboard
  - Latency p99 spike: since when? Correlated with error rate?

Step 3: Trace a slow request
  - Find trace in Tempo/Jaeger: which span is the bottleneck?

Step 4: Deep dive on slow span
  - DB span slow? → check slow query log, EXPLAIN ANALYZE
  - External API slow? → check upstream status page

Step 5: Check pod resources
  - CPU throttling? (rate(container_cpu_throttled_seconds_total))
  - GC pauses? (JVM metrics)
  - Memory pressure?

Step 6: Correlate with deployments
  - Was anything deployed in last hour? git log + deployment history

Step 7: Mitigate first, root cause second
  - Rollback / scale up → restore SLO → then investigate
```

---

## SLI / SLO / SLA

| | Definition | Example |
|-|-----------|---------|
| SLI | Measurement | 99.2% of requests < 200ms |
| SLO | Internal target | 99.5% requests < 200ms |
| SLA | External contract | 99.0% uptime or credits |

**Error budget** = 1 - SLO = the allowed "bad" budget  
99.9% SLO = 8.7 hours of downtime per year allowed

---

## Hands-on Checklist
- [ ] `kube-prometheus-stack` via Helm on Minikube
- [ ] Write 5 PromQL queries: pod CPU, error rate, p99 latency, req rate, memory
- [ ] Grafana: 4-panel dashboard using RED method
- [ ] OTel collector + sample app → traces in Jaeger
