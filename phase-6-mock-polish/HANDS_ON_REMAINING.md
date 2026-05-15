# Hands-On Remaining — DevOps Lab Project

All tasks below require a running cluster. Start with:
```bash
gh workflow run infra-apply.yaml --repo imsameerkhan12/devops-master-prep
# wait ~17 min
gh workflow run bootstrap.yaml --repo imsameerkhan12/devops-master-prep
```

---

## Tier 1 — Core (Do These First)

Directly tied to concepts taught. Zero hands-on done yet.

| # | Task | What to Do |
|---|------|-----------|
| 1 | Deploy **kube-prometheus-stack** | `helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace --set grafana.adminPassword=admin123` |
| 2 | Write 5 PromQL queries on real cluster data | Query in Prometheus UI: request rate, error rate, p99 latency, pod memory, node CPU |
| 3 | Build RED method dashboard in Grafana | 4 panels: req/sec, error rate %, p99 latency, pod count. Use variables for namespace/service |
| 4 | Deploy **Grafana Alloy + Loki**, view logs | `helm install loki grafana/loki-stack` + Alloy DaemonSet → view s3-lister logs in Grafana |
| 5 | Create **ServiceMonitor** for s3-lister | Apply ServiceMonitor CR, verify app appears in Prometheus → Status → Targets |
| 6 | Create **HPA** for s3-lister | Apply HPA CR (cpu: 70%), run `kubectl run load --image=busybox` to stress, watch pods scale |
| 7 | Deploy **KEDA**, create ScaledObject | Install KEDA via Helm, create ScaledObject with Prometheus or HTTP trigger for s3-lister |
| 8 | Deploy **ArgoCD**, migrate s3-lister to GitOps | `helm install argocd argo/argo-cd -n argocd`, create Application CR, delete ci.yaml helm step |

---

## Tier 2 — Important

Good for interviews, builds real depth.

| # | Task | What to Do |
|---|------|-----------|
| 9 | Deploy **External Secrets Operator** | `helm install eso external-secrets/external-secrets`, create ClusterSecretStore + ExternalSecret to sync Docker Hub secret from AWS SM |
| 10 | Apply **PDB** to s3-lister + test | Apply PDB (minAvailable: 1), run `kubectl drain <node> --ignore-daemonsets`, verify only 1 pod evicted at a time |
| 11 | Apply **VPA** in Off mode | Install VPA, apply VPA CR (updateMode: Off), run `kubectl describe vpa s3-lister-vpa` and read recommendations |
| 12 | Create **NetworkPolicy** | Deny all ingress to default namespace, allow only from traefik namespace. Test with `kubectl exec` curl from a pod in different namespace |
| 13 | Create **ResourceQuota + LimitRange** | Apply to default namespace, try to create pod without requests → should get default applied |

---

## Tier 3 — Polish

| # | Task | What to Do |
|---|------|-----------|
| 14 | **cert-manager ClusterIssuer + Certificate** | Needs a real domain pointed at NLB. Create ClusterIssuer (letsencrypt-staging) + Certificate CR. Verify in `kubectl get certificate` |
| 15 | Deploy **Karpenter** | Requires IAM setup + spot/on-demand NodePool. Replace static node group with Karpenter NodePool |
| 16 | **PrometheusRule** — alert for s3-lister | Write PrometheusRule CR for error rate > 1%, verify in Alertmanager UI |

---

## Suggested Session Order

```
Session A — Monitoring (Tier 1: 1→2→3→4→5→16)
  Goal: full observability stack, Grafana dashboards, alerts

Session B — Autoscaling (Tier 1: 6→7, Tier 2: 10→11)
  Goal: HPA + KEDA scaling, PDB protection, VPA recommendations

Session C — GitOps + Secrets (Tier 1: 8, Tier 2: 9)
  Goal: ArgoCD managing s3-lister, ESO syncing secrets from AWS SM

Session D — Policies + Multi-tenancy (Tier 2: 12→13)
  Goal: network isolation, resource quotas

Session E — Polish (Tier 3: 14→15)
  Goal: TLS with real domain, Karpenter node scaling
```

---

## Quick Commands Reference

```bash
# Check cluster is up
kubectl get nodes
kubectl get pods -A

# Port forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Port forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Port forward ArgoCD
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Watch pods scale (HPA test)
kubectl get pods -n default -w

# Watch HPA status
kubectl get hpa -n default -w

# Check VPA recommendations
kubectl describe vpa -n default
```
