# STAR Behavioral Stories — Sameer Khan

## Format Rules
- 2 minutes MAX per story
- First 15 sec: context (hook)
- Middle 75 sec: what YOU did (actions + decisions)
- Last 30 sec: impact + NUMBERS

---

## Story 1: Vault to SSM Migration (Tech Decision + Migration)

**S:** At Compliance Innovation, 50+ microservices were using HashiCorp Vault for secrets management. License cost was significant and the operational overhead (Vault cluster maintenance, unsealing, upgrades) was a recurring burden.

**T:** Migrate to an AWS-native solution — SSM Parameter Store — without any downtime and while maintaining a full audit trail.

**A:** I designed a parallel-sync approach using External Secrets Operator (ESO). I set up SSM Parameter Store with the same secret hierarchy, configured ESO with a SecretStore pointing to AWS SSM using IRSA for auth. Created ExternalSecret CRDs for each service. Tested in dev → staged in test → gradual prod cutover service by service. Kept Vault running for 2 weeks as rollback option. Set up CloudTrail to capture all SSM API calls for audit.

**R:** 50+ services migrated, zero downtime, [X]% monthly cost reduction, audit trail via CloudTrail, simplified ops — no more Vault cluster to maintain.

---

## Story 2: Docker Compose → Helm + K8s Migration (Architecture)

**S:** The Indicios stack was running on Docker Compose — fine for local dev but no orchestration, no auto-scaling, manual deployments in production.

**T:** Migrate to Kubernetes with Helm charts for multi-environment consistency and scalability.

**A:** Created Helm charts with parameterized values.yaml for dev/test/prod environments. Used Pulumi (TypeScript) to provision the EKS cluster and deploy the initial release. Implemented liveness + readiness probes, resource requests/limits, and HPA for autoscaling. Added Prometheus + Grafana via kube-prometheus-stack for observability. Set up ArgoCD for GitOps-based deployments.

**R:** Multi-env parity achieved, automated horizontal scaling, [Y]% deployment time reduction, full observability stack from day one.

---

## Story 3: Production Incident (Failure + Learning)

**S:** [Fill with your real incident — example: secret rotation broke downstream service]

**T:** Restore service ASAP + root cause analysis.

**A:** [Your triage: detected via alert → checked logs → identified root cause → rollback/fix → communicated status]

**R:** [X min resolution time], post-mortem → process change (e.g., staged rotation, canary validation, alert added).

---

## Story 4: Cross-Team Disagreement (Conflict Resolution)

**S:** [Example: Dev team wanted direct kubectl access to production EKS for faster debugging. Security team blocked it citing compliance requirements.]

**T:** Find a solution that satisfies developer productivity needs AND security/compliance requirements.

**A:** Listened to both sides. Proposed GitOps with ArgoCD + PR-based access: devs can push changes via PR (audit trail), RBAC limits what they can do. For debugging: implemented kubectl read-only ClusterRole for devs (no exec, no delete). Documented the trade-offs, demoed the POC to both teams.

**R:** Both teams agreed. Devs got audit-logged debugging access. Security team satisfied with RBAC + no direct exec. Shipped within sprint.

---

## Story 5: Database DevOps at Verizon (Victra) — Leadership

**S:** Victra (Verizon) project had manual DB deployments — schema changes applied by hand, error-prone, no rollback plan, slow (2-hour change windows).

**T:** Lead end-to-end Database DevOps automation using SSDT (SQL Server Data Tools).

**A:** Designed Azure DevOps pipelines for SSDT projects: automated build → unit test → deploy to dev → approval gate → staging → approval → prod. Created branching strategy (feature → dev → release → prod). Built rollback procedure (snapshot before deploy). Set up CloudWatch-equivalent alerts for deployment failures.

**R:** [X]% faster deployments (from 2-hr windows to 15-min automated), [Y]% fewer prod issues, full audit trail for compliance.

---

## Story 6: Why Leaving TokenTide

**S:** I joined TokenTide as an early engineer, built the infra from scratch — EKS cluster, CI/CD pipelines, ESO integration, Grafana observability stack, Pulumi-based provisioning.

**T:** I've achieved what I came to do. Now looking for my next growth challenge.

**A:** Researching companies with stronger engineering culture, larger-scale infrastructure challenges, and a team I can both learn from and contribute to meaningfully.

**R:** Looking for a role where I can operate infrastructure at larger scale, deepen my platform engineering expertise, and have real ownership and impact.
