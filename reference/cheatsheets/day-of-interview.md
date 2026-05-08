# Day-of-Interview Cheatsheet

*Revise this 30 min before your interview. Nothing else.*

---

## K8s Rapid Fire

- Pod phases: Pending → Running → Succeeded/Failed. Errors: ImagePullBackOff, CrashLoopBackOff, OOMKilled, Evicted
- Liveness = RESTART on fail. Readiness = REMOVE from service (no restart)
- QoS eviction: BestEffort first, Burstable middle, Guaranteed last
- Services: ClusterIP (internal), NodePort (dev), LoadBalancer (external), Headless (pod IPs), ExternalName (CNAME)
- RBAC: Role (ns) + ClusterRole (cluster). Bind via RoleBinding or ClusterRoleBinding
- StatefulSet: stable name (pod-0), own PVC, ordered start/stop
- Karpenter > CA: 30s vs 2-10 min, direct EC2, no ASG needed

## AWS Rapid Fire

- SG = stateful (instance). NACL = stateless (subnet, allow+deny)
- IRSA flow: EKS OIDC → SA annotated → pod JWT → STS AssumeRoleWithWebIdentity → temp creds
- Parameter Store (free, manual rotation) vs Secrets Manager ($0.40/secret, auto-rotation)
- S3: Standard → IA → Glacier Instant → Glacier Flexible → Deep Archive
- Karpenter vs CA (same as above)
- 6 WAF pillars: Operational Excellence, Security, Reliability, Performance, Cost, Sustainability

## Networking Rapid Fire

- TCP: SYN → SYN-ACK → ACK (3-way). Reliable, ordered
- DNS records: A (IPv4), AAAA (IPv6), CNAME (alias), MX (mail), TXT (verify/SPF), NS (nameserver)
- /24 = 254 usable IPs (256 - 2). Formula: 2^(32-prefix) - 2
- L4 LB = TCP fast (NLB). L7 LB = HTTP-aware, path routing (ALB, Nginx)
- HTTP: 401 auth, 403 forbidden, 404 not found, 429 rate limit, 502 bad gateway, 503 unavailable, 504 timeout

## IaC Rapid Fire

- OpenTofu = Terraform fork (BSL license change 2023 → Linux Foundation, MPL 2.0, same HCL)
- State: S3 backend + `use_lockfile = true` — DynamoDB NOT needed (OpenTofu 1.8+ / TF 1.10+)
- Never commit tfstate — secrets plaintext inside
- Drift: manual change outside tofu. Detect via `tofu plan` in CI (`-detailed-exitcode`)
- Pulumi = real code (TS/Python/Go). OpenTofu = HCL declarative
- Module: pin with `?ref=v1.2.0` git tag. Never `main` in prod

## CI/CD Rapid Fire

- OIDC: GitHub JWT → AWS STS → temp creds. NO long-lived keys
- Reusable workflow: `on: workflow_call`. Composite action: `action.yml` steps
- Trunk-based branching = modern standard (short-lived branches, PR to main fast)
- Blue-green: instant switch, 2x cost. Canary: gradual, monitor metrics, lower risk

## Observability Rapid Fire

- 3 pillars: Metrics (cheap, aggregated), Logs (events, costly), Traces (journey, microservices)
- RED: Rate, Errors, Duration (services). USE: Utilization, Saturation, Errors (infra)
- Cardinality: never user_id/request_id in metric labels → millions of series → OOM
- SLO burn rate alerts > threshold alerts (less alert fatigue)
- SLI = measurement, SLO = target, SLA = external contract, error budget = 1 - SLO

---

## 5 Mindset Rules

1. STAR + NUMBERS — every behavioral story ends with impact metrics
2. HONEST GAPS — "concept is X, I'd pick it up fast" beats bluffing
3. LOUD THINK — narrate your reasoning on design/debug problems
4. PAUSE IS OK — "let me think for a second" is professional
5. ASK QUESTIONS — 3-5 smart questions at the end
