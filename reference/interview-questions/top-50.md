# Top 50 Interview Questions + Answer Hints

## Kubernetes (15 Qs)

**Q1. Pod stuck in Pending — 5 debug steps?**
1. `kubectl describe pod` → Events section (scheduler reason)
2. Check node resources: `kubectl describe node` → Allocated resources
3. Check for taint/toleration mismatch: `kubectl get node -o yaml | grep taint`
4. PVC bound? `kubectl get pvc -n <ns>`
5. Image issue pre-pull? Check events for ImagePullBackOff

**Q2. Liveness vs Readiness probe — swap effect?**
- Liveness-as-Readiness: traffic reaches unready pods → errors
- Readiness-as-Liveness: slow response → pod restarted → endless crash loop

**Q3. StatefulSet vs Deployment — 4 differences?**
1. Stable pod name (db-0, db-1) vs random (web-abc123)
2. Each pod has own PVC vs shared PVC
3. Ordered start (0→1→2) and stop (2→1→0) vs parallel
4. Headless service per pod DNS vs single service

**Q4. kube-scheduler — how decides pod placement?**
1. Filtering: remove nodes that don't meet requirements (resources, taints, affinity)
2. Scoring: rank remaining nodes (resource balance, affinity preference)
3. Binding: write PodSpec.nodeName

**Q5. Network policy default behavior?**
Default = allow ALL (open). Once a NetworkPolicy selects a pod → whitelist mode (only explicit allow flows).

**Q6. Role vs ClusterRole?**
Role = namespace-scoped permissions. ClusterRole = cluster-wide. Use ClusterRole + RoleBinding for namespace-scoped access to cluster-wide resources (e.g., nodes view).

**Q7. ConfigMap vs Secret?**
ConfigMap = plaintext, for non-sensitive config. Secret = base64-encoded (not encrypted by default!). Enable etcd encryption at rest for real security. Use SSM/ESO for production secrets.

**Q8. Service types — ClusterIP vs NodePort vs LoadBalancer?**
- ClusterIP: internal only (microservices)
- NodePort: node IP + static port (dev/testing)
- LoadBalancer: cloud LB created (production external)

**Q9. Ingress vs Gateway API?**
Ingress: old, vendor-specific annotations, all-in-one config. Gateway API: new standard (GA K8s 1.28+), role-separated (GatewayClass / Gateway / HTTPRoute), vendor-neutral, better multi-tenancy.

**Q10. PVC not bound — possible causes?**
1. No matching StorageClass
2. StorageClass provisioner not installed
3. Requested storage size exceeds available PV
4. Access mode mismatch (requesting RWX but no RWX-capable storage)
5. Node selector on PV doesn't match

**Q11. Pod OOMKilled — steps?**
1. `kubectl describe pod` → Last State: OOMKilled
2. Check `limits.memory` — too low?
3. Check actual usage: `kubectl top pod`
4. Increase memory limit OR fix memory leak in app

**Q12. Cluster Autoscaler vs Karpenter?**
CA: scales ASG (slow 2-10 min, one instance type per group, needs ASG).
Karpenter: direct EC2 provisioning (30s, multi-instance type, spot+OD mix, no ASG needed).

**Q13. Helm rollback internally?**
Each release stored as K8s Secret (`helm.sh/release.v1`). Rollback = re-apply the YAML from previous revision's Secret. Previous release Secrets retained (configurable max history).

**Q14. Pod-to-pod communication (full flow)?**
`pod-a → DNS lookup (CoreDNS) → ClusterIP → iptables/kube-proxy → iptables DNAT → pod-b IP`
With VPC CNI: pod-b IP is real VPC IP, no NAT.

**Q15. K8s upgrade strategy?**
1. Upgrade control plane first (kube-apiserver, controller-manager, scheduler)
2. Upgrade kube-proxy + CoreDNS add-ons
3. Upgrade node groups (drain → cordon → new AMI → uncordon)
4. Verify workloads after each step
5. Never skip minor versions

---

## AWS / Cloud (12 Qs)

**Q1. Security Group vs NACL?**
SG = stateful (instance level, return traffic auto-allowed, allow-only).
NACL = stateless (subnet level, separate in+out rules, allow+deny).

**Q2. Public vs private subnet?**
Public: route table has 0.0.0.0/0 → Internet Gateway.
Private: route table has 0.0.0.0/0 → NAT Gateway.

**Q3. IAM Role vs IAM User?**
User = long-term credentials (humans). Role = temporary STS credentials (services, cross-account, EKS pods via IRSA). Prefer roles always.

**Q4. IRSA?**
EKS OIDC provider → K8s SA annotated with role ARN → pod gets projected JWT → AWS SDK calls STS AssumeRoleWithWebIdentity → temp credentials. Pod-level IAM (not shared node IAM).

**Q5. S3 bucket went public — audit + fix?**
Audit: CloudTrail → who changed Block Public Access. Check bucket policy + ACL.
Fix: Enable all 4 Block Public Access settings. Remove public bucket policy. Review ACLs. Enable S3 Access Analyzer.

**Q6. Parameter Store vs Secrets Manager?**
SSM: free standard, manual rotation, good for static config.
SM: $0.40/secret/month, auto-rotation for RDS/Aurora, JSON secrets.

**Q7. EKS pod S3 access — best practice?**
IRSA: create IAM role with S3 policy, annotate K8s ServiceAccount, pod gets temp credentials via STS. Never use access keys inside pods.

**Q8. Multi-region active-active vs active-passive?**
Active-active: zero RTO, zero RPO, double cost, complex data sync (conflict resolution for writes).
Active-passive: 5-min RTO, <1s RPO (Aurora Global), half cost, simpler. Use for most production.

**Q9. AWS bill 3x suddenly?**
1. Cost Explorer → filter by service, by day → find spike
2. Trusted Advisor → unusual usage
3. Check: EKS control plane left running, NAT Gateway data transfer, EC2 running over weekend, S3 data transfer

**Q10. RDS Multi-AZ vs Read Replica?**
Multi-AZ: synchronous, HA/failover (60-120s auto), no read scale.
Read Replica: asynchronous (lag), read scale, can be cross-region.

**Q11. Spot interruption handling?**
1. 2-min warning via instance metadata + CloudWatch event
2. Graceful shutdown: SIGTERM to app, drain connections
3. Use `--interrupt-handling` in Karpenter (auto cordon + drain)
4. Stateless apps only on Spot, stateful on On-demand

**Q12. ALB vs NLB?**
ALB: L7 (HTTP), path/host routing, WAF, target group health checks, WebSocket, Auth.
NLB: L4 (TCP/UDP), ultra-low latency, static IP, TLS pass-through, gaming/IoT.

---

## IaC + CI/CD (10 Qs)

**Q0. Terraform vs OpenTofu?**
HashiCorp changed Terraform license to BSL 1.1 (Aug 2023) — no longer open source. OpenTofu is the Linux Foundation fork (MPL 2.0), drop-in replacement, same HCL syntax, same state format. IBM acquired HashiCorp in 2024. Community standard is now OpenTofu.

**Q1. OpenTofu state corrupt — recovery?**
1. Check S3 versioning — restore previous version of tfstate
2. `tofu state pull > state-backup.json`
3. Manually edit state JSON (last resort)
4. `tofu import` to re-import resources one by one
5. Never run `tofu apply` on corrupted state

**Q2. Drift detection in production?**
`tofu plan -detailed-exitcode` in CI/CD daily. Exit code 2 = drift exists → alert. Tools: Atlantis (PR-based), driftctl.

**Q3. Pulumi vs OpenTofu?**
OpenTofu: HCL declarative, huge module registry, simple infra, truly open source. Pulumi: real programming languages (TS/Python/Go), complex logic, type safety, unit tests. Use OpenTofu for straightforward infra + team familiarity. Use Pulumi for conditional logic + multi-cloud abstractions.

**Q3b. OpenTofu state locking?**
S3 native locking with `use_lockfile = true` (OpenTofu 1.8+ / Terraform 1.10+). No DynamoDB table needed — S3 conditional writes handle the lock file (`.tfstate.tflock`). Old approach was DynamoDB — avoid in new setups.

**Q4. Multi-env module structure?**
```
infra/
├── modules/vpc/    # reusable
├── modules/eks/
└── envs/
    ├── dev/        # uses modules, dev tfvars, dev S3 state
    ├── staging/
    └── prod/       # separate AWS account ideally
```

**Q5. GitHub Actions OIDC with AWS?**
1. AWS: create OIDC provider for token.actions.githubusercontent.com
2. Create IAM role + trust policy with repo condition
3. Workflow: `permissions: id-token: write`
4. Use `aws-actions/configure-aws-credentials@v4` with `role-to-assume`
5. No long-lived keys ever stored in GitHub

**Q6. Self-hosted vs GitHub-hosted runner?**
GitHub-hosted: free, clean env per run, no maintenance. Self-hosted: access to private network, custom AMI, more control, you maintain.

**Q7. Pipeline secrets — secure handling?**
GitHub: Secrets + OIDC (preferred). Azure DevOps: Variable Groups linked to Key Vault. Never print secrets in logs. Mask secrets in pipeline output.

**Q8. Blue-green vs Canary?**
Blue-green: all-or-nothing switch at LB, fast rollback, needs 2× resources.
Canary: gradual (5% → 25% → 100%), monitor metrics at each step, catch issues early, slower rollout.

**Q9. Helm vs Kustomize?**
Helm: full lifecycle management, templates, hooks, rollback, versioned charts, packaging. Kustomize: overlay-based (no templates), native in kubectl, simpler. Use Helm for complex apps. Use Kustomize for simple patches on top of upstream manifests.

**Q10. GitOps (ArgoCD/Flux) workflow?**
1. Developer pushes code → CI builds + pushes image
2. CI updates image tag in Git (infra repo)
3. ArgoCD detects Git diff → syncs to cluster
4. K8s reconciles to desired state
5. ArgoCD health check → alerts if degraded

---

## Observability + Debugging (8 Qs)

**Q1. Production app slow — methodology?**
7 steps: confirm scope → RED dashboard → trace slow request → deep dive slow span → check pod resources → correlate with deployments → mitigate first then RCA.

**Q2. Prometheus cardinality explosion?**
Each label combination = 1 time series. High-card labels (user_id, request_id) → millions of series → OOM. Avoid: no high-cardinality values in metric labels. Detect: `topk(10, count by (__name__)(...))`.

**Q3. RED vs USE?**
RED (services): Rate, Errors, Duration. USE (infra): Utilization, Saturation, Errors.

**Q4. Distributed trace — how to read?**
TraceID = one request end-to-end. Spans = individual operations. Waterfall view: find widest span = bottleneck. Check span tags for errors. Follow TraceContext header (traceparent) propagation.

**Q5. Loki vs ELK?**
Loki: labels-only index (cheap), best with Grafana, LogQL. ELK: full-text index (expensive), powerful search, needs Elasticsearch cluster. K8s + cost → Loki. Enterprise full-text search → ELK.

**Q6. Alert fatigue — how to solve?**
1. SLO burn-rate alerts instead of threshold alerts
2. Deduplicate similar alerts (Alertmanager grouping)
3. Silence during deploys automatically
4. Review alert history: close unused alerts monthly
5. Escalation policies: page only if burning budget fast

**Q7. SLI/SLO/SLA with examples?**
SLI = measurement ("99.2% requests < 200ms last 30 days").
SLO = target ("99.5% requests < 200ms").
SLA = external contract ("99.0% uptime, credits if violated").
Error budget = 1 - SLO = 0.5% = 2.16 hours/month allowed downtime.

**Q8. OTel collector pipeline?**
Receivers (OTLP, Jaeger, Prometheus scrape) → Processors (batch, sampling, attribute filter, memory limiter) → Exporters (Tempo, Datadog, Jaeger, Prometheus remote write).

---

## Behavioral (5 Qs)

**Q1. Biggest production incident?**
[Use your real story — prepare STAR format with: what happened, your role, steps to recover, what changed after]

**Q2. Disagreement with team lead?**
[Story 4 — dev access vs security. Proposed middle ground, demo'd POC, both sides agreed]

**Q3. Complex migration?**
[Story 1 — Vault to SSM. 50+ services, zero downtime, parallel sync, ESO, gradual cutover]

**Q4. Why leaving?**
Growth + scale. "Ready for larger infrastructure challenges. TokenTide was great for building from scratch — now I want to operate at higher scale with stronger engineering culture."

**Q5. 5-year plan?**
"Staff SRE / Principal DevOps or Platform Engineering Lead — own developer experience and platform reliability at scale."
