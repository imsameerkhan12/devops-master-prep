# Day 14: System Design + Mock Round 1

## Universal Framework (15-minute response)

```
0-2 min:   CLARIFY — "Functional requirements? Scale (users, req/sec)? SLA targets? Budget?"
2-4 min:   CONSTRAINTS + TRADE-OFFS — cost vs perf, consistency vs availability, build vs buy
4-9 min:   HIGH-LEVEL ARCHITECTURE — draw boxes + arrows, name all components
9-12 min:  DEEP DIVE — 1-2 critical components, articulate trade-offs ("chose X over Y because...")
12-14 min: SCALE + FAILURE — 10x traffic? Single point of failure? DR plan?
14-15 min: MONITORING + COST — key metrics, alerts, rough $/month estimate
```

---

## Template 1: CI/CD for 50 Microservices

**Clarify:** Mono-repo or poly-repo? Languages? Current state? Deployment target (K8s)?

**Architecture:**
```
GitHub (mono-repo)
  → GitHub Actions (changed-service detection via path filters)
    → Build matrix (only affected services)
      → Test in parallel
        → Docker build → ECR push (OIDC, no long-lived keys)
          → ArgoCD (GitOps) → EKS deploy
            → Helm rollback / ArgoCD app rollback
```

**Trade-offs:**
- Mono-repo: unified versioning, single CI config. Con: slow CI, noisy history
- Poly-repo: isolated, faster CI. Con: sync overhead, duplicated pipelines
- Reusable workflows per language (Java pipeline, Node pipeline)

**Secrets:** OIDC to AWS, External Secrets Operator in cluster  
**Rollback:** ArgoCD app rollback in 5 min  
**Monitoring:** Deployment frequency, lead time, failure rate, MTTR (DORA metrics)

---

## Template 2: Multi-Region DR

**Clarify:** RTO/RPO targets? Active-active or active-passive? Budget?

**Architecture (Active-Passive, cost-optimized):**
```
Primary (us-east-1):
  EKS cluster + full traffic
  Aurora PostgreSQL (writer)
  S3 bucket

DR (us-west-2):
  EKS cluster (scaled down, warm standby)
  Aurora Global DB (read replica, < 1s lag)
  S3 CRR (cross-region replication)

Route53:
  Health check on primary ALB
  Failover routing policy → DR if primary unhealthy
  RTO: ~5 min (DNS TTL 60s + app startup)
  RPO: < 1 second (Aurora Global DB)
```

**Failover:** Auto (Route53 health check) or Manual (runbook)  
**Caveat:** In-flight transactions, stateful connections — need graceful draining

---

## Template 3: Observability for 1000-Service Platform

**Clarify:** Current state? Metric volume? Log volume? Budget for observability?

**Architecture:**
```
Metrics:
  Per-cluster Prometheus → Thanos (long-term, cross-cluster)
  Cardinality budget: max 100k series per cluster
  No user_id/request_id labels in metrics

Logs:
  Promtail (K8s) → Loki (labels-only index, cheap)
  CloudWatch → for AWS service logs
  Sampling: high-volume services 1% (errors always 100%)

Traces:
  OTel Collector → Tempo
  Sampling: 1% at edge, 100% on error paths

Dashboards:
  Grafana, dashboards-as-code (JSON in Git)
  RED method per service, USE method per node

Alerting:
  Alertmanager → PagerDuty
  SLO burn rate alerts (not threshold spam)
  Noise reduction: deduplicate, group, silence during deploy

Cost target: Observability < 5% of total infra cost
```

---

## Key Trade-offs to Articulate

| Decision | Option A | Option B | Choose When |
|----------|----------|----------|-------------|
| Cost vs Performance | Spot instances | On-demand | Stateless=Spot, critical=On-demand |
| Consistency vs Availability | Global lock (consistent) | Eventual (available) | Depends on business requirement |
| Simplicity vs Flexibility | Helm templates | Pulumi code | Simple app=Helm, complex infra=Pulumi |
| Build vs Buy | In-house Vault | AWS Secrets Manager | Small team=Buy, compliance=In-house |

---

## Hands-on Checklist
- [ ] Self-mock 75 min: phone record, 45 min design loud, 30 min review recording
- [ ] Pramp/peer mock: schedule
- [ ] Draw 3 system design problems on paper (1-page sketch each)
