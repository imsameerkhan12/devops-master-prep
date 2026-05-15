# Day 1: Setup + STAR Story Bank

## Checklist
- [ ] Minikube install + start + `kubectl get nodes` verify
- [ ] `kubectl` + `helm` installed — `kubectl version`, `helm version`
- [ ] Docker Desktop running
- [ ] AWS CLI configured — `aws configure`
- [ ] Terraform installed — `terraform version`
- [ ] VS Code extensions: Kubernetes, Terraform, Docker, YAML, GitLens
- [ ] KillerCoda account created, 1 scenario tried
- [ ] GitHub repo `devops-prep-2026` created
- [ ] AWS Billing Alert set at $5

---

## STAR Format

**S**ituation → **T**ask → **A**ction → **R**esult

Rules:
- 2 minutes max per story
- Result MUST have numbers
- First 15 sec: context | Middle: what you did | Last 30 sec: impact

---

## My 6 STAR Stories

### 1. Vault to SSM Migration
**S:** Compliance Innovation — 50+ services on HashiCorp Vault. License cost high, ops overhead.  
**T:** Migrate to AWS-native (SSM Parameter Store) without downtime, maintain audit trail.  
**A:** Designed parallel-sync using ESO. Configured SecretStore + ExternalSecret CRDs. Tested dev → staged → gradual prod cutover. Kept Vault live for 2-week rollback window.  
**R:** 50+ services migrated, zero downtime, [X]% cost reduction, audit via CloudTrail.

### 2. Docker Compose to Helm Migration
**S:** Indicios stack on Docker Compose — works locally, no orchestration/scaling in prod.  
**T:** Migrate to K8s + Helm for multi-env consistency.  
**A:** Created Helm chart (dev/test/prod values). Used Pulumi for EKS provisioning. Added health checks, resource limits, HPA. Grafana dashboards for observability.  
**R:** Multi-env parity, automated scaling, [Y]% deployment time reduction, end-to-end observability.

### 3. Production Incident
**S:** [Fill in real incident — secret rotation broke service / DNS misconfig / wrong terraform apply]  
**T:** Restore service + RCA.  
**A:** [Triage steps — logs, alerts, rollback, comms]  
**R:** [Resolution time], post-mortem changes.

### 4. Cross-team Disagreement
**S:** [Dev team wanted direct EKS access, security pushed back]  
**T:** Balance both teams' needs.  
**A:** Proposed GitOps (PR-based access for devs + RBAC for security). Documented trade-offs, demo'd POC.  
**R:** Both agreed, [metric].

### 5. Database DevOps — Verizon (Victra)
**S:** DB deployments at Victra were manual — error-prone, slow.  
**T:** Lead end-to-end Database DevOps with SSDT.  
**A:** Azure DevOps pipelines for SSDT: build → test → deploy across envs. Branching strategy + rollback + alerting.  
**R:** [X]% faster deployments, [Y]% fewer prod issues, audit-compliant.

### 6. Why Leaving (TokenTide)
**S:** At TokenTide, doing good infra work.  
**T:** Looking for larger scale / stronger engineering culture / specific growth.  
**A:** Researching and applying selectively.  
**R:** Want next role where I can [specific contribution + grow].

---

## Top 10 Behavioral Questions — Quick Answers

1. Biggest production failure → use Story 3
2. Team conflict → use Story 4
3. Tight deadline → prep separately (reduce scope, communicate early)
4. Cross-team disagreement → use Story 4
5. Mentoring junior → prep separately
6. Pushed back on bad decision → Story 4 variant
7. Learned new tech quickly → Pulumi / ESO story
8. Multiple priorities balance → "prioritize by impact + communicate"
9. Why leaving → Story 6
10. 5-year plan → "Staff/Principal SRE or Platform Engineering Lead — specific, not vague"
