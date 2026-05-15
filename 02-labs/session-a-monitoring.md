# Session A — Monitoring
> kube-prometheus-stack · PromQL · RED Dashboard · Alloy · Loki · ServiceMonitor

---

## Task 1: Deploy kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set grafana.adminPassword=admin123

kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

---

## Task 2: 5 PromQL Queries

Run in Prometheus UI at `localhost:9090`

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
```

---

## Task 3: RED Dashboard in Grafana (4 panels)

| Panel | Query | Visualization |
|-------|-------|---------------|
| Request rate | `sum(rate(http_requests_total[5m]))` | Time series |
| Error rate % | `rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100` | Time series |
| p99 latency | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` | Time series |
| Pod count | `count(kube_pod_status_running{namespace="default"})` | Stat |

---

## Task 4: Grafana Alloy + Loki

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm upgrade --install loki grafana/loki --namespace monitoring \
  --set loki.commonConfig.replication_factor=1 \
  --set loki.storage.type=filesystem \
  --set singleBinary.replicas=1

helm upgrade --install alloy grafana/alloy --namespace monitoring
# Add Loki datasource in Grafana UI → Explore → see logs
```

---

## Task 5: ServiceMonitor for s3-lister

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

## Task 16 (bonus): PrometheusRule — Alert

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
spec:
  groups:
  - name: s3-lister
    rules:
    - alert: HighErrorRate
      expr: |
        rate(http_requests_total{status=~"5.."}[5m])
        / rate(http_requests_total[5m]) > 0.01
      for: 5m
      labels:
        severity: critical
```

```bash
kubectl apply -f prometheusrule.yaml
# Verify: Prometheus UI → Alerts
```

---

## Grafana Dashboard Import IDs

| Dashboard | ID |
|-----------|----|
| K8s cluster overview | 315 |
| Node Exporter full | 1860 |
| K8s pods | 6417 |
| Traefik | 17347 |
