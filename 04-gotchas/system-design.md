# System Design Framework

## Universal 15-Minute Template

```
[0-2 min]   CLARIFY
  - Functional requirements (what must the system do?)
  - Scale: users/day, requests/sec, data volume
  - SLA targets: uptime, latency (p99?)
  - Budget constraints
  - Geographic distribution (single region / multi-region?)
  - Existing tech stack?

[2-4 min]   CONSTRAINTS + TRADE-OFFS
  - Cost vs Performance (spot vs on-demand, caching trade-offs)
  - Consistency vs Availability (CAP theorem, eventual vs strong)
  - Simplicity vs Flexibility (managed service vs custom)
  - Build vs Buy (in-house vs SaaS)

[4-9 min]   HIGH-LEVEL ARCHITECTURE
  - Draw boxes and arrows
  - User → CDN → LB → API → Cache → DB
  - Name every component
  - Call out data flow

[9-12 min]  DEEP DIVE (pick 1-2 critical components)
  - Why this choice over alternatives?
  - Trade-offs articulated: "chose X over Y because..."
  - Failure modes of this component

[12-14 min] SCALE + FAILURE
  - 10x traffic: what breaks first?
  - Single points of failure?
  - Data loss scenarios?
  - DR strategy?

[14-15 min] MONITORING + COST
  - Key SLIs to monitor
  - Alert strategy
  - Rough $/month estimate
```

---

## Template 1: CI/CD for 50 Microservices

```
GitHub (mono-repo or poly-repo)
  → GitHub Actions
      [Detect changed services via path filters]
      → Matrix build (parallel, only changed services)
      → Test (unit + integration)
      → Docker build → ECR push (OIDC auth)
      → Update image tag in infra Git repo
  → ArgoCD (GitOps)
      [Detects Git change → syncs to K8s]
      → Helm upgrade in EKS
      → Health check → alert if degraded
```

**Key decisions:**
- Mono-repo: unified versioning, simpler CI reuse. Con: slow CI on large repos
- Poly-repo: isolated, faster CI. Con: sync overhead across repos
- Reusable workflows per language stack
- OIDC for AWS auth (no long-lived keys)
- ArgoCD for deploy (declarative, Git is source of truth)
- Rollback: `argocd app rollback myapp` (uses Helm history)

**Monitoring:** Deployment frequency, lead time, change failure rate, MTTR (DORA)

---

## Template 2: Multi-Region DR

```
Primary Region (us-east-1):
  Route53 → ALB → EKS (full scale) → Aurora PostgreSQL (writer)
                                    → S3 (CRR enabled)
  ElastiCache Redis (cluster mode)

DR Region (us-west-2):
  Route53 → ALB → EKS (scaled down, warm standby)
           → Aurora Global DB (read replica, <1s lag)
           → S3 (replica bucket)

Failover trigger:
  Route53 health check → if primary ALB returns 5xx → failover to DR
  RTO: ~5 min (DNS TTL 60s + pod startup)
  RPO: <1 second (Aurora Global DB)
```

**Trade-offs:**
- Active-Passive chosen over Active-Active: 50% less cost, acceptable RTO/RPO
- Aurora Global DB over manual replication: managed, sub-second lag
- S3 CRR: async (slight data loss possible vs multi-region consistency)

---

## Template 3: Observability for 1000-Service Platform

```
Metrics pipeline:
  Per-cluster Prometheus → Thanos (sidecar + store gateway)
  → Object storage (S3 for long-term)
  → Grafana (multi-cluster, templated dashboards)

Log pipeline:
  Promtail (K8s nodes) → Loki (labels-only index)
  CloudWatch → for AWS service logs
  Log levels: INFO+ in prod, DEBUG in dev only
  Sampling: 1% for high-volume healthy paths, 100% for errors

Trace pipeline:
  OTel SDK (apps) → OTel Collector (per cluster)
  → Tempo (Grafana stack)
  Sampling: tail-based (1% overall, 100% on error)

Alerting:
  Alertmanager → PagerDuty (critical)
               → Slack (warning)
  Alert strategy: SLO burn rate (not static threshold)
  Grouping + deduplication + silence-during-deploy

Cost target: < 5% of total infra cost for observability
```

---

## Template 4: Secrets at Scale (1000 services × 5 envs)

```
5000 secrets total

AWS SSM Parameter Store hierarchy:
  /org/env/service/secret-name
  /org/production/payment-service/db-password

K8s integration: External Secrets Operator (ESO)
  → SecretStore (per cluster, IRSA auth)
  → ExternalSecret CRDs (per service)
  → K8s Secret (auto-synced, refreshInterval=1h)

Rotation:
  Static secrets: manual (Parameter Store + ESO refresh)
  DB passwords: Secrets Manager + Lambda rotation

Audit:
  CloudTrail: every SSM API call logged
  K8s: ExternalSecret events + sync status

Access control:
  IRSA per service → each service only reads its secrets
  No cross-service secret access
```

---

## Template 5: Zero-Downtime Deploys

```
Pre-deploy:
  → Health checks passing (readiness probe)
  → PodDisruptionBudget (minAvailable: 80%)

Deploy (Canary via Argo Rollouts):
  → 5% traffic to new version
  → Monitor: error rate, latency p99, success rate
  → Auto-promote if healthy 10 min
  → Auto-rollback if error rate > threshold

During rollout:
  → Graceful shutdown (terminationGracePeriodSeconds: 60)
  → SIGTERM → app drains connections → exits 0
  → Connection draining on ALB target group

Post-deploy:
  → Integration tests against production
  → Smoke test on canary subset
  → On failure: automatic rollback to previous Helm revision
```
