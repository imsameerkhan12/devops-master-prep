# Resume Interview Guide — Sameer Khan

> Use this: Read the **Context** block before the interview. STAR stories — memorize the ARC, not word-for-word.
> Numbers in **bold** — have these ready without thinking.

---

## TELL ME ABOUT YOURSELF (script — memorize this)

> "I'm a Senior DevOps and Cloud Engineer with about 5 years of experience. I've worked across AWS, GCP, and Azure —
> primarily with Kubernetes: EKS, GKE, and AKS. My core strength is setting up and operating cloud-native platforms —
> EKS with Pulumi IaC, Helm-based deployments, GitHub Actions CI/CD, and production observability with Grafana.
> I've also done complex work like migrating Docker Compose stacks to Helm on EKS, and secrets management migrations
> from self-managed Vault to AWS SSM with External Secrets Operator.
> I hold a CKA certification. Currently at TokenTide as a DevOps Engineer, before that 16 months at Compliance Innovation
> doing multi-cloud Kubernetes work. Started my career at Cybage where I did Database DevOps for Verizon and built
> mobile CI/CD pipelines for Android and iOS."

**If they follow up "what kind of work are you looking for?":**
> "I want to go deeper on platform engineering — building the internal platform that product teams use.
> Autoscaling, GitOps, observability, secrets management. The kind of work where the infra becomes invisible to developers."

---

## QUICK REFERENCE CARD

| Company | Duration | Role | Key Tech |
|---------|----------|------|----------|
| TokenTide | Nov 2025–Present | DevOps Engineer | EKS, Minikube, Pulumi, Dgraph, Grafana |
| Compliance Innovation | Jul 2024–Nov 2025 | Senior Cloud Engineer | EKS, GKE, Helm, Pulumi Operator, Neo4j, Vault→SSM, ESO, Cloudflare |
| Cybage | Jul 2021–Jul 2024 | DevOps Engineer | AKS, ACI, Azure DevOps, SSDT, GraphQL, Terraform, Android+iOS CI/CD |

| Certification | Number | Relevance |
|---------------|--------|-----------|
| CKA (Certified Kubernetes Administrator) | LF-ig7ixm4i9p | Core K8s — networking, storage, RBAC, troubleshooting |
| AZ-900 (Azure Fundamentals) | I324-1514 | Azure core services, pricing, compliance |
| AZ-204 (Azure Developer Associate) | 1453-0384 | App Service, ACI, ACR, Azure Functions, CosmosDB |

---

---

# COMPANY 1: TokenTide (Nov 2025 – Present)

## WHAT WAS THE PROJECT?

TokenTide is a remote-first startup. You are working as a DevOps Engineer.
The company has software services (exact product domain not critical — focus on infra work).
Tech stack uses Dgraph (graph database) as a key data store.
Services need to run across multiple environments — local dev + cloud (Dev/Test/Prod).

**What you can say when asked "what does TokenTide do / what was the project?"**
> "TokenTide is a startup I'm currently with as a DevOps Engineer. My work there is platform and infrastructure —
> setting up and running the Kubernetes infrastructure on EKS, managing deployments using Pulumi IaC,
> and building out the full observability stack with Grafana, Prometheus, and Loki for all environments."

## WHAT I CONTRIBUTED

| Area | What I did |
|------|-----------|
| Kubernetes setup | Set up AWS EKS as the cloud cluster (Dev/Test/Prod). Configured Minikube as the local dev environment so developers can run the full stack on their laptops using the same Helm charts. |
| Ingress | Set up NGINX Ingress Controller for routing — services accessible via NGINX on both EKS and Minikube. |
| IaC | Wrote Pulumi TypeScript to deploy Dgraph database as a StatefulSet across Dev, Test, and Prod environments. Each environment gets its own config via Pulumi stacks. |
| Observability | Built Grafana dashboards covering logs and infrastructure metrics for all three cloud environments. |

---

## Architecture Diagram — TokenTide

```
Developer Laptop
  └── Minikube
        └── Same Helm charts as EKS (developers test locally before pushing)
        └── NGINX Ingress → routes to services

AWS EKS (3 environments: Dev / Test / Prod)
  ├── NGINX Ingress Controller
  │     └── Routes traffic to → Services → Pods
  ├── Dgraph StatefulSet (deployed via Pulumi IaC)
  │     ├── Dev stack  → 1 replica, small storage
  │     ├── Test stack → 2 replicas
  │     └── Prod stack → 3 replicas, large storage
  └── Observability Stack
        ├── Prometheus → scrapes /metrics from all services
        ├── Grafana    → dashboards (infrastructure metrics + logs)
        └── Loki       → log aggregation from all environments

Pulumi (TypeScript) → manages Dgraph across all 3 EKS environments
GitHub Actions       → CI/CD for service deployments
```

---

## Technology Explainers — TokenTide

### What is Dgraph?
Graph database — data stored as nodes and edges, not tables and rows.
Use case: relationship-heavy data — social graphs, knowledge graphs, recommendation systems.
Uses GraphQL natively as query language (not SQL, not Cypher).
Why we used it: application data model was highly relational — entities connected by typed relationships.
Difference from Neo4j: both are graph DBs. Neo4j uses Cypher query language, Dgraph uses GraphQL/DQL. Dgraph is distributed by design.

### What is Gateway API + HTTPRoute?
New Kubernetes standard replacing NGINX Ingress. Three roles:
- `GatewayClass` — cluster infra team defines (once)
- `Gateway` — cluster team owns (once per cluster)
- `HTTPRoute` — each dev team owns their own route

This means product teams manage their own routing rules without touching shared infra config.
NGINX Ingress was a monolithic config — one wrong annotation could break all services.

### Why Minikube alongside EKS?
EKS = production cloud. Minikube = developer laptop. Same Helm charts, same values files (dev.values.yaml).
Developers run `helm install` locally → works exactly like EKS → no "works on my machine" issues.

---

## STAR Stories — TokenTide

### STAR 1 — Setting Up EKS Platform + Minikube for Local Dev

**S:** TokenTide needed a proper cloud Kubernetes setup. Services needed to run on cloud (Dev/Test/Prod on EKS) and developers needed a local environment that behaved identically to the cloud — so "works on my machine" issues don't reach production.

**T:** Set up EKS as the cloud cluster, configure NGINX Ingress for routing, and establish Minikube as the standard local dev environment using the same Helm charts as production.

**A:** Provisioned EKS cluster. Set up NGINX Ingress Controller — configured routing rules for all services. Wrote Helm charts with environment-specific values files (local.values.yaml for Minikube, dev.values.yaml / test.values.yaml / prod.values.yaml for EKS). Minikube setup: developers run `helm install` with local values — same chart, smaller resource requests, no PVCs in local. Cloud setup: GitHub Actions deploys using environment-specific values to the right EKS cluster.

**R:** All 3 cloud environments on EKS with consistent Helm-based deployments. Developers run identical stack locally on Minikube — no environment drift between local and cloud.

**Numbers:** **3 cloud environments** (Dev/Test/Prod on EKS) + local dev on Minikube, **same Helm charts** across all, zero environment drift.

---

### STAR 2 — Dgraph Multi-Environment Pulumi IaC

**S:** Dgraph needed deployment across Dev, Test, and Prod with different configs — different replica counts, different storage sizes, different resource limits. Doing this manually meant drift — Prod had tunings that Dev didn't know about.

**T:** Deploy Dgraph across all three environments from a single codebase with environment-specific config.

**A:** Used Pulumi TypeScript — defined Dgraph as a StatefulSet with PersistentVolumeClaims. Environment config (replicas, storage class, resource limits) passed via `pulumi.Config` — one config value per environment. Same TypeScript code, three `pulumi up` commands with different stack configs. Added health checks so Pulumi waits for Dgraph to be ready before marking deployment complete.

**R:** Zero environment drift. Any config change goes through code review before reaching Prod. Dev, Test, Prod all provably identical structure, only scale differs.

**Numbers:** **3 environments**, **1 Pulumi codebase**, StatefulSet with PVCs, environment-specific via `pulumi.Config`.

---

### STAR 3 — End-to-End Observability with Grafana

**S:** No visibility into what was running. Issues discovered by users reporting errors, not by the team seeing dashboards spike.

**T:** Full observability across all three environments — logs and metrics in one place.

**A:** Deployed kube-prometheus-stack (Prometheus + Grafana + Alertmanager) per environment. Built **RED method dashboards** for each service: request rate (req/sec), error rate (% 5xx), duration (p99 via histogram_quantile). Added **USE method panels** for infrastructure: node CPU utilization, memory saturation, disk. Connected Loki for log aggregation — same Grafana, switch datasource from Prometheus to Loki for logs. Set up Alertmanager routing to Slack for error rate spikes.

**R:** Team catches issues before users do. Dashboards used daily for release health checks.

---

## Q&A — TokenTide

**Q: Why EKS and not GKE or AKS?**
> "AWS is the primary cloud for TokenTide — services already used S3, IAM, etc. EKS gives the tightest AWS integration — Pod Identity for IAM, native VPC networking, managed add-ons. Moving to GKE would have meant re-architecting IAM, storage, and networking integrations. EKS was the obvious fit."

**Q: Why Pulumi and not Terraform for Dgraph?**
> "Dgraph deployment had conditional logic — different replica counts, different storage classes per environment. In Terraform, doing this with `count` and `for_each` gets ugly fast — you end up with workarounds for what's a simple if/else. Pulumi lets me write TypeScript — real conditionals, functions, loops. I can define a `getDgraphConfig(environment)` function that returns the right config and it reads like normal code. For straightforward cloud infra like VPCs and IAM, I'd still use Terraform — the community ecosystem is bigger. But for application-level IaC with logic, Pulumi wins."

**Q: What Grafana dashboards specifically did you build?**
> "Two types per environment. Service dashboards using RED method — request rate (rate of req/sec using counter metric), error rate (percentage of 5xx responses), and p99 latency using histogram_quantile on duration histograms. Infrastructure dashboards using USE method — node CPU utilization, memory saturation, disk. Each service dashboard had namespace and service as dropdown variables so the same dashboard template worked for all services without duplicating panels."

**Q: What ingress did you use on EKS at TokenTide?**
> "NGINX Ingress Controller. Set it up on both EKS (cloud environments) and Minikube (local dev). NGINX Ingress reads Ingress objects and routes traffic to the right services. Same ingress config works on both — developers can test routing locally on Minikube before pushing to EKS."

**Q: Why Minikube for local dev and not something like kind or k3d?**
> "Minikube is the most straightforward for developers who aren't deep into K8s — good documentation, `minikube tunnel` for LoadBalancer services, `minikube addons enable ingress` for NGINX. Kind and k3d are also valid options and faster. At TokenTide, Minikube was the established choice — same Helm charts as EKS, just different values files for resource sizing."

**Trap question: "You mentioned Minikube — isn't that just for testing? You used it in a production context?"**
> "Minikube is local development only — not production. Production and all cloud environments run on EKS. The value is that the same Helm charts work on both — developers run `helm install` with local values on Minikube, verify behavior, then push. We maintain separate values files: one for local (small resource requests, no PVCs), environment-specific ones for each EKS environment. Same chart, different values."

---

---

# COMPANY 2: Compliance Innovation Pvt Ltd (Jul 2024 – Nov 2025)

## Projects Under This Company
- **OnyxPlus / Indicios (Telos)** — Docker Compose → Helm, Pulumi + Pulumi Operator, Neo4j + S3 backups
- **Simplici / Liquidity** — GitHub Actions CI/CD, Vault → SSM migration, ESO, GKE onboarding, Cloudflare DNS

---

## WHAT WAS THE PROJECT? — OnyxPlus / Indicios (Telos)

**Client:** Telos.
**Product:** Indicios — a data verification and attestation platform. OnyxPlus is the identity/credential layer on top of it. Think of it as: verifiable credentials / digital identity for enterprise use.
**Tech stack:** Multiple microservices, Neo4j as the graph database (relationships between credentials, identities, verifications).
**Deployed on:** EKS (cloud) and Minikube (local dev).

**What you can say when asked "what was this project?"**
> "Indicios is a digital identity and data verification platform built for the client Telos. It had multiple services and used Neo4j as the graph database — because identity and credential relationships are naturally graph-shaped. My work was all infrastructure: the entire stack was running on Docker Compose on VMs before I joined. I migrated it to Kubernetes — Helm charts for each service, Pulumi to orchestrate the deployment, and the Pulumi Operator for GitOps-style automatic updates."

## WHAT I CONTRIBUTED — OnyxPlus / Indicios

| Area | What I did |
|------|-----------|
| Containerization | Services were already containerized (Docker Compose) — I created Helm charts for each service: Deployment, Service, ConfigMap, Secrets, readiness probes. |
| K8s migration | Moved the whole stack from Docker Compose on VMs to EKS via Helm. Set deployment order: databases first (Neo4j), then dependent services. |
| IaC | Used Pulumi TypeScript to orchestrate Helm chart installations and manage deployment order. |
| Pulumi Operator | Installed Pulumi Operator in cluster — Git push to Pulumi code repo → Operator detects change → runs `pulumi up` automatically. GitOps for infra. |
| Neo4j backups | Built K8s CronJob: daily `neo4j-admin dump` → S3 with timestamp. IAM via Pod Identity. 30-day lifecycle policy. Tested restore. |

**Before you joined:** Docker Compose on VMs. Manual `docker-compose up`. No rolling deployments. Environment drift between environments.
**After your work:** Services on EKS with Helm, Pulumi Operator handling infra GitOps, Neo4j backed up daily to S3.

---

## Architecture Diagram — OnyxPlus / Indicios

```
BEFORE:
  VM → docker-compose up → containers running manually
  No rollback, no health checks, downtime during updates

AFTER:

  Git (Pulumi code)
       │
       ▼
  Pulumi Operator (K8s controller, watches Stack CRs in cluster)
       │ detects git change, runs pulumi up automatically
       ▼
  EKS Cluster
    ├── Helm Release: Service A (OnyxPlus identity layer)
    │     └── Deployment → Pod (readiness probe verified before next step)
    ├── Helm Release: Service B (Indicios core)
    │     └── Deployment → Pod
    ├── Helm Release: Neo4j StatefulSet
    │     └── PersistentVolumeClaim (data survives pod restart)
    │
    └── CronJob (daily at 2am)
          └── neo4j-admin dump → gzip → aws s3 cp → s3://backup-bucket/neo4j-YYYY-MM-DD.dump
                                                        └── S3 Lifecycle: delete after 30 days

  Minikube (developer laptops)
    └── Same Helm charts, dev.values.yaml (no PVC, smaller requests)
```

---

## Technology Explainers — OnyxPlus/Indicios

### What is the Pulumi Operator?
Normal Pulumi: you run `pulumi up` from your laptop or CI pipeline.
Pulumi Operator: a Kubernetes controller. You define a `Stack` custom resource in K8s pointing to your Pulumi program in Git. The operator watches for commits — when you push new Pulumi code, the operator detects the change and runs `pulumi up` automatically inside the cluster. It's GitOps for infrastructure. Git is the source of truth, operator reconciles actual state. No CI pipeline needed to trigger infra changes.

```yaml
# Stack CR — tells operator "watch this git repo, run pulumi up when it changes"
apiVersion: pulumi.com/v1
kind: Stack
metadata:
  name: indicios-stack
spec:
  stack: org/indicios/dev
  projectRepo: https://github.com/company/indicios-infra
  branch: main
  envRefs:
    PULUMI_ACCESS_TOKEN:
      type: Secret
      secret:
        name: pulumi-token
        key: token
```

### What is Neo4j?
Graph database. Data = nodes (entities) + relationships (edges) + properties on both.
Neo4j query language = Cypher (`MATCH (u:User)-[:FOLLOWS]->(p:Person) RETURN p`).
Why better than SQL for graph queries: a 3-hop relationship query that takes multiple JOINs in SQL takes one Cypher line. Performance difference is dramatic when relationships are deeply nested.
Backup: `neo4j-admin dump --database=neo4j --to=/backups/neo4j.dump` then `neo4j-admin load` to restore.

### What is a CronJob in K8s?
Like a cron task but running as a K8s Pod. Defined schedule in cron syntax.
For Neo4j backup: runs daily, mounts the Neo4j data, runs `neo4j-admin dump`, uploads to S3, exits. Pod disappears after job completes. History kept (last N successful + failed pods for debugging).

---

## STAR Stories — OnyxPlus/Indicios

### STAR 1 — Docker Compose to Helm Migration

**S:** Indicios application stack ran on Docker Compose on VMs. Developers manually ran `docker-compose up/down`. Deployments caused downtime. No rollback. Config drift between environments — production had tunings dev didn't know about.

**T:** Migrate entire multi-service stack to Kubernetes-native Helm deployment. IaC so any developer can deploy the full stack.

**A:** Audited the Docker Compose file — every service, volume, network, environment variable listed. Created a Helm chart per service: Deployment, Service, ConfigMap for non-sensitive config, Secret (referenced from ESO or direct for initial migration), readiness probe on each pod. Used Pulumi TypeScript to orchestrate chart installation order — databases first (Neo4j StatefulSet), wait for readiness probe to pass, then install dependent services. Installed Pulumi Operator so infra changes happen automatically on git push — no CI step needed.

**R:** Full stack running on EKS. Rolling deployments — zero downtime during updates. Any engineer runs `pulumi up` or pushes to Git and the Operator handles it. Environment parity: Dev, Staging, Prod all from same charts.

**Numbers:** Multiple services migrated, **zero downtime** rolling updates, readiness-probe-ordered deployment, **1 Pulumi TypeScript codebase** for all environments.

---

### STAR 2 — Neo4j S3 Backup with Automated Recovery

**S:** Neo4j database running in K8s with no backup strategy. Persistent volume failure or accidental deletion = total data loss. No tested recovery process.

**T:** Automated daily backups with tested restore and defined RTO.

**A:** Created Kubernetes CronJob running daily at 2am. Pod mounts Neo4j data directory, runs `neo4j-admin dump --database=neo4j --to=/tmp/backup.dump`. Compresses with gzip. ServiceAccount on the CronJob pod mapped via Pod Identity to IAM role with S3 write permissions on the backup bucket — no static credentials anywhere. S3 object key = `neo4j-backup-YYYY-MM-DD.dump.gz` so files are timestamped. S3 lifecycle policy = delete after 30 days. Tested restore: copied latest dump to a staging Neo4j pod, ran `neo4j-admin load`, verified data integrity by running Cypher queries against known records.

**R:** Daily automated backups running without manual intervention. Restore tested — **~30 min RTO** for full Neo4j restore. **30-day retention** window. No static credentials — IAM via Pod Identity.

---

## WHAT WAS THE PROJECT? — Simplici / Liquidity

**Products:**
- **Simplici** — a compliance and KYC (Know Your Customer) automation platform. Helps businesses verify customer identities for regulatory compliance.
- **Liquidity** — a financial services platform, likely related to Simplici's client base (liquidity management or payments).

**What you can say when asked "what was Simplici/Liquidity?"**
> "Simplici was a compliance and KYC platform — it automated customer identity verification for businesses. Liquidity was a related financial product. My work was infrastructure: CI/CD pipelines, secrets management migration from Vault to AWS SSM, External Secrets Operator implementation, onboarding workloads to GKE for a client requirement, and Cloudflare DNS for all public-facing services."

## WHAT I CONTRIBUTED — Simplici / Liquidity

| Area | What I did |
|------|-----------|
| CI/CD | Built GitHub Actions workflows: build → SonarQube scan → push to ECR → Helm deploy to EKS or GKE |
| Secrets migration | Migrated all secrets from self-managed HashiCorp Vault → AWS SSM Parameter Store. Service by service, zero downtime. |
| ESO | Deployed External Secrets Operator with ClusterSecretStore (AWS SSM). Created ExternalSecret CRs for each app. 1-hour refresh. |
| GKE onboarding | Onboarded multiple apps to GKE (client requirement). Standardized Helm chart template. Workload Identity for GCP auth. |
| DNS | Managed all DNS via Cloudflare — public services via proxy mode (DDoS protection), internal via DNS-only. |

## Architecture Diagram — Simplici / Liquidity

```
BEFORE (secrets):
  Self-managed HashiCorp Vault on a VM
    └── Manual unsealing after restart
    └── Manual token rotation
    └── Single point of failure for ALL application secrets

AFTER (secrets):
  AWS SSM Parameter Store (managed, KMS-encrypted, CloudTrail audited)
       │
       ▼
  External Secrets Operator (ESO) in K8s cluster
    ├── ClusterSecretStore → authenticates to AWS SSM via Pod Identity
    └── ExternalSecret CRs → define "fetch /app/db-password → K8s Secret db-creds"
          └── Refreshes every 1 hour automatically
                └── Application Pod → reads K8s Secret (doesn't know about SSM)

CI/CD (GitHub Actions):
  Push to main
    ├── Build Docker image
    ├── Run tests + SonarQube scan
    ├── Push to ECR
    └── helm upgrade --install → EKS (or GKE for client workloads)

Multi-cloud:
  AWS EKS  ←─── primary workloads (Simplici)
  GCP GKE  ←─── client requirement workloads (Liquidity)
                  └── Workload Identity (GCP equiv of Pod Identity)

DNS (Cloudflare):
  Domain → Cloudflare (proxy mode = DDoS protection + cache)
         → AWS NLB or GKE Load Balancer
  Internal services → DNS-only mode (grey cloud = direct routing)
```

---

## Technology Explainers — Simplici/Liquidity

### What is HashiCorp Vault?
Open-source secrets manager. You deploy it yourself on a VM or K8s. Stores secrets encrypted. Applications authenticate (via AppRole, K8s auth, etc.) and get temporary tokens to fetch secrets.
Problem: self-managed = your responsibility to keep it running, unsealed, tokens rotated. If Vault goes down, apps can't fetch secrets — production outage.

### What is AWS SSM Parameter Store?
AWS-managed secrets storage. No servers to run. Two types: String (plaintext) and SecureString (KMS encrypted).
Benefits over self-managed Vault: zero operational overhead, native IAM auth, CloudTrail audit log of every access, built-in versioning. Cost: free for standard params, $0.05/parameter/month for advanced.

### What is External Secrets Operator (ESO)?
K8s controller. Syncs secrets from external systems (SSM, Secrets Manager, Vault) into native K8s Secrets.
Two key CRDs:
- `ClusterSecretStore` — authenticates to the external system (e.g., SSM in us-east-1 via Pod Identity)
- `ExternalSecret` — says "fetch this SSM parameter, create this K8s Secret key"

Application reads a normal K8s Secret. Doesn't know about SSM. ESO handles the sync on `refreshInterval`.

```yaml
# ExternalSecret — says: fetch /app/db-password from SSM, put in K8s Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-db-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-ssm-store
    kind: ClusterSecretStore
  target:
    name: db-creds           # K8s Secret name created by ESO
  data:
  - secretKey: password      # key in K8s Secret
    remoteRef:
      key: /app/db-password  # SSM Parameter path
```

### What is Cloudflare (and why use it)?
DNS provider + reverse proxy. When you set a record with "proxy" (orange cloud): traffic goes through Cloudflare servers before reaching your origin. Cloudflare adds DDoS protection, caching, SSL termination, WAF. When "DNS only" (grey cloud): direct routing to your IP, no Cloudflare proxy. Used for public-facing services (orange cloud) and internal services (grey cloud). Managed via Terraform Cloudflare provider — no manual UI changes.

### What is Workload Identity (GKE)?
GKE equivalent of EKS Pod Identity. Allows K8s ServiceAccounts to authenticate as GCP Service Accounts without static credentials. Annotation on K8s SA: `iam.gke.io/gcp-service-account: name@project.iam.gserviceaccount.com`. GKE injects credentials into pod automatically. Same concept as AWS Pod Identity, different implementation.

---

## STAR Stories — Simplici/Liquidity

### STAR 1 — Vault to AWS SSM Migration

**S:** Compliance Innovation had self-managed HashiCorp Vault on a VM. Every Vault restart required manual unsealing — the vault doesn't auto-unseal without paid enterprise or additional setup. Manual token rotation. On-call burden when Vault went down — all apps blocked on secrets. Single point of failure.

**T:** Migrate all application secrets to AWS SSM Parameter Store. Zero downtime. Zero secrets exposed during migration.

**A:** First, audited all secrets in Vault — listed every path, categorized by sensitivity. Created matching parameters in AWS SSM as `SecureString` type (KMS-encrypted at rest). Deployed ESO with a `ClusterSecretStore` pointing at SSM, authenticating via Pod Identity — no static credentials on the ESO controller. Migrated one service at a time: update app deployment to read from ESO-synced K8s Secret → deploy → verify app works → delete the Vault entry. After all services migrated, decommissioned Vault VM.

**R:** Zero Vault operational burden. Secrets managed via AWS — no manual unsealing, no token rotation, CloudTrail audit log on every access. ESO refreshes every **1 hour** — any SSM update reflects in cluster without pod restart. Vault fully decommissioned.

---

### STAR 2 — GKE Onboarding with Standardized Patterns

**S:** Compliance Innovation expanded from AWS (EKS) to GCP (GKE) for client requirement. No established pattern for GKE deployments — risk of each app team doing things differently, same mistakes repeated.

**T:** Onboard applications to GKE with same deployment quality as EKS. Create reusable pattern so other engineers can follow.

**A:** Created a reusable base Helm chart: Deployment with standard structure (resource requests/limits, liveness/readiness probes, anti-affinity for HA), Service, HPA (optional), optional Ingress. Used `values.yaml` overrides for each app — no copy-paste of full templates. Set up Workload Identity for apps needing GCP resource access (GCS, Pub/Sub). GitHub Actions workflow with `google-github-actions/auth` using Workload Identity Federation (same OIDC concept as AWS). Documented the pattern with an onboarding checklist.

**R:** Multiple applications onboarded to GKE with consistent patterns. Same Helm chart structure as EKS — only cloud-specific values differ. New app onboarding time cut significantly. Pattern documented — no tribal knowledge required.

---

### STAR 3 — GitHub Actions CI/CD for Multi-Environment Deployments

**S:** Application deployments at Compliance Innovation were manual — developer SSH into server, run docker commands, or manually trigger Helm upgrades. High risk of human error. No consistent build/test/deploy process across services.

**T:** Automated CI/CD for all services across EKS and GKE environments with test gating.

**A:** Built GitHub Actions workflows: trigger on push to main or PR. Steps: checkout → Docker build → SonarQube code quality scan (fails pipeline if quality gate not met) → push image to ECR (for EKS) or GCR/Artifact Registry (for GKE) → `helm upgrade --install` with environment-specific values. Used OIDC (OpenID Connect) for both AWS and GCP auth — no long-lived credentials in GitHub secrets. Environment separation via GitHub Environments with required reviewers for Prod deploys.

**R:** Zero manual deployments. Every code change goes through the same tested pipeline. SonarQube catches code issues before they reach Prod.

---

## Q&A — Compliance Innovation

**Q: Walk me through the Vault to SSM migration. Any risks?**
> "Main risk was the cutover window — between creating the SSM parameter and the app switching to ESO, there's a brief period where both exist. We managed it by running both in parallel: app still reads from Vault via old config, ESO syncs SSM to K8s Secret, we verify K8s Secret has the right value, then update the app deployment to use the K8s Secret. Only then delete the Vault entry. One service at a time — if anything went wrong, roll back that one service, not everything. No secrets were exposed because SSM values were created independently, not copied through an insecure path."

**Q: What is the Pulumi Operator and how does it differ from ArgoCD?**
> "Pulumi Operator = GitOps for infrastructure code. It runs Pulumi programs (TypeScript, Python, Go) and manages cloud resources — VPCs, IAM roles, RDS instances, Helm releases. ArgoCD = GitOps for Kubernetes manifests — it syncs YAML from Git to the cluster. They're complementary: Pulumi Operator handles the cloud infra layer, ArgoCD handles the K8s application layer. At Compliance Innovation I used Pulumi Operator because our infra and application deployment were both written in Pulumi TypeScript — unified tooling."

**Q: What SonarQube does and how did you integrate it?**
> "SonarQube is a code quality and security scanner. It analyzes code for bugs, vulnerabilities, code smells, and test coverage. In GitHub Actions, we ran it as a step in the CI pipeline using the SonarQube GitHub Action or Maven/Gradle plugin. The pipeline waits for the SonarQube Quality Gate — if issues exceed configured thresholds, the gate fails and the pipeline stops. No deployment happens with failing quality gate. SonarQube server was self-hosted (or cloud) and connected via a SONAR_TOKEN secret."

**Q: Why Cloudflare and not Route53 for DNS?**
> "Route53 is just DNS. Cloudflare adds a reverse proxy layer on top — DDoS protection, WAF, caching, SSL termination, all at the CDN edge before traffic even reaches your load balancer. For public-facing services, that's real protection. Also Cloudflare's free tier covers most of what small teams need. Route53 is better if you're deeply integrated in AWS (alias records to ALB, health checks for failover) — we used both: Cloudflare for public domain DNS, Route53 for internal AWS service discovery."

**Q: What is Neo4j? Why use it over PostgreSQL?**
> "Neo4j is a graph database. Data is stored as nodes (entities) and relationships (edges) with properties on both. Query language is Cypher — `MATCH (a:User)-[:FOLLOWS]->(b:User) RETURN b`. For relationship-heavy queries, Neo4j is dramatically faster than PostgreSQL — a 3-hop relationship traversal that needs 3 JOINs and a complex query in SQL is one Cypher line. PostgreSQL is better for tabular data with complex aggregations, transactions across multiple entities, or when you need ACID guarantees across the whole dataset. We chose Neo4j because Indicios data model was fundamentally graph-shaped."

**Q: How did Neo4j backup and restore work exactly?**
> "`neo4j-admin dump` creates a binary snapshot of the database — not a SQL dump, a proprietary format. Restore is `neo4j-admin load`. The CronJob pod mounted the Neo4j data volume (ReadOnlyMany PVC access or backup done while Neo4j is in maintenance mode), ran dump, uploaded compressed file to S3. Key detail: Neo4j should ideally be in consistent state during dump — we ran it during low-traffic window (2am). Restore tested on staging: spin up empty Neo4j pod, copy dump from S3, run load command, start Neo4j, run Cypher verification queries. Took **~30 minutes** for our database size."

**Trap question: "You mentioned ESO refreshes every 1 hour. What if a secret is rotated urgently — do apps need to wait an hour?"**
> "No — two options. First, you can trigger an immediate sync by annotating the ExternalSecret: `kubectl annotate externalsecret app-secret force-sync=$(date +%s)`. Second, if the secret is already synced to K8s, you can also directly update the K8s Secret and it takes effect on the next pod restart or volume refresh. The 1-hour interval is the automatic background refresh — emergency rotation doesn't have to wait for it."

---

---

# COMPANY 3: Cybage Software Pvt Ltd (Jul 2021 – Jul 2024)

## Projects Under This Company
- **Victra (Verizon)** — Database DevOps with SSDT, Android + iOS CI/CD via Azure DevOps
- **MIS Dashboard** — Microservices on AKS, SpringBoot + GraphQL API Gateway, Terraform + GitHub Actions

---

## Context Block — Cybage

Cybage is a software services and IT consulting company based in Pune. You worked there for 3 years (Jul 2021 – Jul 2024) as a DevOps Engineer. Client work — you served different clients.

---

## WHAT WAS THE PROJECT? — Victra (Verizon)

**Client:** Victra — Verizon's largest authorized retail partner in the USA. They sell Verizon phones and plans through thousands of retail stores.

**What you can say when asked "what was Victra/Verizon?"**
> "Victra is Verizon's largest authorized retailer — thousands of physical stores across the US. I worked on their DevOps setup at Cybage. Two main pieces: first was Database DevOps — they had SQL Server databases being deployed manually by DBAs, and I automated that end-to-end using SSDT and Azure DevOps pipelines. Second was their mobile apps — Android and iOS retail store apps that were being built and submitted to stores manually. I automated those CI/CD pipelines with Azure DevOps."

## WHAT I CONTRIBUTED — Victra

| Area | What I did |
|------|-----------|
| Database DevOps | Implemented SSDT (SQL Server Data Tools) — schema defined as a VS project in Git. Azure DevOps pipeline: build .dacpac → deploy to Dev/Staging/Prod via SqlPackage. Change management gate on Prod. |
| Android CI/CD | Azure DevOps pipeline: Gradle build → sign (keystore from Azure DevOps Library) → Google Play Developer API upload. |
| iOS CI/CD | Azure DevOps pipeline: Xcode build on macOS agent → sign (.p12 + .mobileprovision from Secure Files) → Fastlane to TestFlight. |

**Before:** DBAs ran ALTER TABLE scripts manually in production. Mobile builds done manually on developer machines, submitted by hand.
**After:** Zero manual database deployments. Mobile apps: push code → 30 min → build in Google Play / TestFlight.

---

## WHAT WAS THE PROJECT? — MIS Dashboard

**What it was:** An internal Management Information System dashboard at Cybage (or for a client) that aggregated data from multiple backend services — inventory, sales, HR, finance. The frontend needed data from all these systems in one view.

**What you can say when asked "what was the MIS Dashboard?"**
> "MIS Dashboard was a management reporting platform that pulled data from multiple backend services — inventory, sales, HR, finance — into one unified dashboard. The challenge was aggregating data from different services efficiently. We implemented GraphQL as the API gateway using HotChocolate in ASP.NET Core — schema stitching combined all service schemas into one. Frontend makes one GraphQL query, gateway fans out to relevant services in parallel. Infrastructure was on AKS with Terraform for provisioning and GitHub Actions for CI/CD."

## WHAT I CONTRIBUTED — MIS Dashboard

| Area | What I did |
|------|-----------|
| Microservices | Containerized SpringBoot Java services using Maven + Docker multi-stage builds |
| GraphQL gateway | Implemented HotChocolate GraphQL server in ASP.NET Core — schema stitching across all microservices |
| Infrastructure | Terraform: AKS cluster + Azure MySQL + Azure SQL Server + ACR |
| CI/CD | GitHub Actions: Maven/Docker build → push to ACR → Helm deploy to AKS |
| DB migrations | Flyway: version-controlled SQL migration scripts, runs before app deploy |
| Containerization | Java + .NET apps containerized, images pushed to DockerHub (dev) and ACR (prod) |

---

---

## Architecture Diagram — Victra Database DevOps

```
BEFORE:
  DBA manually runs ALTER TABLE scripts in production
  High risk, no audit trail, no rollback

AFTER:

  Git Repository (SSDT Visual Studio Project)
    └── Schema defined as .sql files, versioned like app code
         │ Git PR → code review → merge to main
         ▼
  Azure DevOps Pipeline
    ├── Step 1: Build SSDT project → generates .dacpac artifact
    │           (dacpac = declarative schema snapshot, not a script)
    ├── Step 2: Deploy to Dev SQL Server
    │           SqlPackage compares .dacpac vs live DB → generates diff → applies
    ├── Step 3: Deploy to Staging (same process)
    ├── Step 4: Change Management gate
    │           Pipeline blocked until change ticket approved
    └── Step 5: Deploy to Prod SQL Server (only after approval)
                Full audit trail in Azure DevOps pipeline logs

ROLLBACK:
  Re-run pipeline with previous .dacpac artifact tag
  SqlPackage generates reverse diff and applies
```

---

## Architecture Diagram — Victra Mobile CI/CD

```
Android Pipeline:
  Git push → Azure DevOps
    ├── Android SDK build agent
    ├── Gradle build → unsigned .apk
    ├── Sign with keystore (from Azure DevOps Library secure variable)
    ├── Google Play Developer API → upload to internal track
    └── ~30 min total → build visible in Google Play Console

iOS Pipeline:
  Git push → Azure DevOps
    ├── macOS hosted agent (Azure DevOps hosted macOS pool)
    ├── Xcode build → unsigned .ipa
    ├── Sign with:
    │   ├── .p12 certificate (from Secure Files)
    │   └── .mobileprovision profile (from Secure Files)
    │   └── Installed in macOS keychain at build time, cleaned after
    ├── Fastlane deliver → App Store Connect (TestFlight)
    └── ~30 min total → build in TestFlight

Triggers:
  - Every commit → debug build (for QA testing)
  - Git tag (v1.2.3) → release build (production store submission)
```

---

## Architecture Diagram — MIS Dashboard

```
React Frontend (browser)
    │ Single GraphQL query (e.g., "give me sales + inventory for Q1")
    ▼
HotChocolate GraphQL Gateway (ASP.NET Core)
    ├── Schema stitching: combines schemas from all microservices
    ├── Fans out query to relevant services in parallel
    └── Aggregates responses → returns unified result to frontend
         │
    ┌────┼────────────────────────────────────┐
    ▼    ▼                 ▼                  ▼
Service A        Service B          Service C      Service D
(Inventory)      (Sales)            (HR)           (Finance)
SpringBoot API   SpringBoot API     SpringBoot      SpringBoot
    │                │
Azure MySQL     Azure SQL Server
(relational)    (data warehouse)

Flyway: runs DB migrations before each service deploy
        schema_history table tracks which V1__, V2__ scripts ran

Infrastructure (Terraform):
  AKS cluster (node pools: system + user)
  Azure MySQL
  Azure SQL Server
  Azure Container Registry (ACR)
  → All automated, new environment = terraform apply

CI/CD (GitHub Actions):
  Code push → build Docker image → push to ACR → helm upgrade on AKS
```

---

## Technology Explainers — Cybage

### What is SSDT (SQL Server Data Tools)?
A Visual Studio extension that lets you define a SQL Server database schema as a project — tables, views, stored procedures, indexes as `.sql` files. The project is stored in Git like application code. You do NOT write manual ALTER TABLE scripts. Instead:
1. Open Visual Studio → change table schema in SSDT designer
2. SSDT generates the `.sql` file change
3. Git commit + PR → code review
4. Pipeline builds `.dacpac` (database schema snapshot artifact)
5. SqlPackage tool compares `.dacpac` against live database → generates exact diff → applies only what changed
No manual scripts. No human error in ALTER TABLE syntax. Full audit trail.

### What is .dacpac?
Database Application Component Package. Binary file that represents the desired schema state of a SQL Server database. SqlPackage compares it against the live database and generates and runs the exact SQL needed to get from current state to desired state. Declarative — you declare desired state, tool figures out the migration.

### What is SqlPackage?
Microsoft command-line tool that works with .dacpac files. Key commands:
- `SqlPackage /Action:Publish` — deploy dacpac to SQL Server (generates and runs diff)
- `SqlPackage /Action:Script` — preview what SQL would run (dry run)
- `SqlPackage /Action:Extract` — create dacpac from existing database

### What is HotChocolate?
.NET library for building GraphQL servers (like Apollo Server but for C#/.NET). Used to implement our API gateway. Features: schema stitching (combining multiple service schemas into one unified schema), automatic DataLoader for N+1 query prevention, subscription support. We exposed a single `/graphql` endpoint — frontend sent one query, HotChocolate resolved it across multiple microservices.

### What is GraphQL (and why as API gateway)?
Query language for APIs. Client specifies exactly the fields it wants — no overfetching (getting fields you don't need) or underfetching (making multiple calls). As API gateway: schema stitching merges schemas from multiple microservices into one unified schema. Frontend makes one query, gateway fans out to relevant services, combines results. Before: frontend made 5 REST calls to 5 services. After: 1 GraphQL query, gateway handles the fan-out.

### What is Flyway?
Database migration tool. You write SQL scripts with version prefix: `V1__create_users.sql`, `V2__add_email_column.sql`. Flyway maintains a `flyway_schema_history` table tracking which versions ran. On deploy: runs only new migrations in order. Idempotent — re-running doesn't re-apply old migrations. We ran Flyway as first step before app deploy — schema changes always before the code that depends on them.

### What is Maven?
Java build tool. `pom.xml` defines dependencies and build config. Key commands: `mvn clean install` (compile + test + package into .jar). Used for SpringBoot Java services — Maven builds the .jar, Docker packages it into an image.

### What is Azure Container Instances (ACI)?
Serverless containers on Azure — no K8s, no cluster, just "run this container image". Faster to start than AKS (no node provisioning). We used ACI for simple stateless services that didn't need K8s features. AKS for the full microservices stack. Decision: if you need K8s features (HPA, service mesh, RBAC) → AKS. If you need a quick isolated container run without cluster overhead → ACI.

---

## STAR Stories — Cybage

### STAR 1 — Database DevOps for Victra (Verizon)

**S:** Victra (Verizon's largest authorized retailer) had manual SQL Server database deployments. DBAs ran ALTER TABLE scripts by hand in production. High risk — wrong syntax in a manual script could lock a production table. No audit trail of who ran what. No rollback procedure.

**T:** Automate end-to-end database deployment from Git to production via Azure DevOps. Zero manual steps in production.

**A:** Implemented SSDT — database schema defined as a Visual Studio project in Git. Every schema change = Git PR → code review (DBA reviews schema, not just developers). Pipeline: compile SSDT project → generate .dacpac artifact → SqlPackage deploy to Dev/Staging → change management gate (pipeline blocked until ITSM ticket approved) → SqlPackage deploy to Prod. Added pre-deployment validation scripts and post-deployment verification queries.

The hardest part was change management: DBAs had done manual deployments for years and didn't trust the automated pipeline for production. We ran parallel mode for 1 month — both manual DBA and automated pipeline applied the same changes. Zero discrepancies. That evidence built the confidence to fully switch.

**R:** Zero manual database deployments for Victra. Full audit trail in Azure DevOps. Rollback = re-run pipeline with previous .dacpac. DBAs now focused on query optimization and schema design instead of risky manual deployments.

**Numbers:** **3 environments** (Dev/Staging/Prod), full Azure DevOps pipeline, **zero manual steps**, 1-month parallel validation before cutover.

---

### STAR 2 — Android + iOS CI/CD to Production

**S:** Victra mobile apps (Android + iOS) were built manually on developer machines and submitted to stores by hand. Builds took a full day. Blocked on specific machines with specific signing credentials. Error-prone — wrong build variant sometimes submitted.

**T:** Fully automated CI/CD for both Android and iOS to production stores. Any developer triggers a release, pipeline handles signing and submission.

**A:** **Android:** Azure DevOps pipeline with Android SDK agent. Gradle build → sign with keystore stored in Azure DevOps Library (variable group, encrypted) → upload to Google Play internal track via Google Play Developer API. **iOS:** macOS build agent (Azure DevOps hosted macOS pool). Xcode build → sign with .p12 certificate + .mobileprovision profile stored as Azure DevOps Secure Files → Fastlane for App Store Connect submission to TestFlight. Two triggers: every commit builds debug (for QA), Git tag (v1.x.x) builds release (for store submission). Certificates stored encrypted, downloaded at build time to agent keychain, cleaned up after.

**R:** Both Android and iOS fully automated. Dev pushes code → **~30 minutes** → build in Google Play internal track or TestFlight. Release = tag the commit, not a manual store upload. Signing credentials never on developer machines.

---

### STAR 3 — MIS Dashboard Microservices on AKS

**S:** Client needed a Management Information System aggregating data from inventory, sales, HR, and finance systems. Frontend was making 5 separate REST calls to different teams' services — slow, inconsistent data shapes, frontend team blocked waiting for backend contract agreements.

**T:** Unified API layer for all microservices on AKS with automated infrastructure and CI/CD.

**A:** Designed microservices — each domain (inventory, sales, HR, finance) as independent SpringBoot service. Implemented HotChocolate GraphQL gateway in ASP.NET Core — schema stitching merged all service schemas into one. Frontend sends one GraphQL query, gateway fans out in parallel, combines results. Terraform for infrastructure: AKS cluster (system + user node pools), Azure MySQL, Azure SQL Server, ACR — all automated. GitHub Actions CI/CD: Maven build → Docker image → push to ACR → Helm upgrade on AKS. Flyway for DB migrations as first pipeline step.

**R:** MIS Dashboard live on AKS. 1 GraphQL query replaces 5 REST calls. Frontend team works against one stable schema contract. New environment = `terraform apply` + pipeline run.

---

### STAR 4 — Containerization of Java and .NET Apps

**S:** Java (SpringBoot) and .NET applications at Cybage were running on application servers (Tomcat, IIS) — long deploy cycles, environment-specific configs, "works on my machine" issues. Moving to AKS required containerization.

**T:** Containerize all applications and push to DockerHub/ACR for K8s deployment.

**A:** Java (SpringBoot): Maven builds .jar, Dockerfile uses multi-stage build — build stage with Maven/JDK, final stage with JRE only (smaller image). .NET: multi-stage Dockerfile with .NET SDK for build, .NET Runtime for final image. Images tagged with Git commit SHA for traceability. Pushed to DockerHub (for dev images) and ACR (for production — private, Azure-native auth). Helm charts deploy the versioned image tags.

**R:** All apps containerized. Consistent behavior across Dev/Staging/Prod — same image, different values. Image tag = Git SHA = full traceability from running container back to exact commit.

---

## Q&A — Cybage

**Q: What is SSDT and Database DevOps? Explain simply.**
> "SSDT lets you treat your SQL Server database schema like source code. Instead of writing ALTER TABLE scripts manually, you define the database in a Visual Studio project — tables, views, indexes as .sql files in Git. When you build the project, it creates a .dacpac (schema snapshot). SqlPackage compares the .dacpac against the live database and figures out the exact SQL needed to bring the live DB in sync — you declare the desired state, the tool handles the migration. Same principle as Terraform for infrastructure — declare desired state, apply diff."

**Q: What's the biggest challenge in Database DevOps?**
> "The human side, not the technical side. The pipeline was straightforward to build. Getting DBAs to trust an automated pipeline for production databases — that took a month of running parallel (manual + automated) with zero discrepancies before they were confident. Technical implementation is maybe 20% of the challenge. Change management — explaining the risk model, building confidence through evidence — is the other 80%."

**Q: What is GraphQL and why as API gateway, not REST?**
> "GraphQL is a query language where the client specifies exactly the fields it needs — no overfetching. As an API gateway using schema stitching, HotChocolate merged the schemas from all our microservices into one unified graph. The frontend sends one query like 'give me user.name, user.orders.total, user.inventory.count' and the gateway resolves each field from the relevant microservice in parallel. Before: frontend made 5 REST calls and combined data itself — duplicated logic, fragile. After: gateway owns the composition, frontend gets exactly what it asked for in one request."

**Q: What is Flyway? Why not just run SQL scripts manually?**
> "Flyway tracks which migrations have been applied in a `flyway_schema_history` table in the database. Scripts are named with a version prefix — V1, V2, etc. On deploy, Flyway runs only new versions in order. Re-running doesn't re-apply old migrations — it's idempotent. Manual scripts have no tracking — you might run V3 before V2, or run V1 twice, or forget to run it in staging. Flyway eliminates all of that. It runs as a pipeline step before the application starts — schema is always ready before the app that depends on it."

**Q: Explain ACI (Azure Container Instances) vs AKS.**
> "ACI is serverless containers — you give Azure an image and it runs the container without you managing any cluster. Fast startup, simple. No K8s features though — no HPA, no service mesh, no RBAC at pod level, no persistent volumes beyond Azure File shares. AKS is full Kubernetes — you manage the cluster, get all K8s features. We used both: ACI for simple, stateless services that didn't need K8s complexity (quick utility services, batch jobs), AKS for the main microservices platform. Rule of thumb: if you need orchestration features → AKS. If you just need to run a container → ACI."

**Q: How did you handle iOS signing securely?**
> "iOS requires a .p12 signing certificate and a .mobileprovision profile — both sensitive. We stored them as Azure DevOps Secure Files — encrypted at rest, only accessible to authorized pipelines. At build time, the pipeline downloads them to the macOS build agent, imports the .p12 into the keychain with a build-time password (from a secret variable). Xcode picks them up automatically. After the build, cleanup step removes them from the keychain — they don't persist on the agent. Certificates are rotated annually, Azure DevOps file updated, no pipeline YAML change needed."

**Trap question: "You used both DockerHub and ACR — why two registries?"**
> "DockerHub for development images — easier access for local dev, free for public images, no auth setup needed to pull. ACR for production — private registry inside Azure, native AKS auth (no credentials needed in cluster, managed identity pulls), geo-replication available, integrated vulnerability scanning. DockerHub has rate limits on pulls from CI environments which can be a problem — ACR doesn't. For prod images that go to AKS, always ACR. DockerHub was convenience for dev workflow."

---

---

# CROSS-PROJECT QUESTIONS

**Q: You've used Pulumi AND Terraform. When do you choose which?**
> "Terraform for standard cloud infrastructure — VPCs, RDS, IAM, S3, security groups. HCL is readable, Terraform provider ecosystem is massive, state management is mature. Pulumi when the IaC needs real programming logic — at Compliance Innovation, Dgraph deployment had per-environment conditional logic (replicas, storage class, resource limits). Writing that in HCL `count`/`for_each` gets messy. In TypeScript, it's a function. Also Pulumi's orchestration (waiting for readiness, ordering dependent installs) is cleaner than Terraform's depends_on chains. Rule: if you're fighting HCL to express logic, switch to Pulumi."

**Q: EKS vs GKE vs AKS — what are the real differences?**
> "Same Kubernetes API — your Helm charts and manifests work on all three. Differences are in integration and management. EKS: best AWS integration (Pod Identity, VPC CNI, EBS CSI, ALB controller). You manage node groups explicitly — more control, more responsibility. Karpenter is the modern autoscaler. GKE: best managed experience — Autopilot mode, Google manages nodes completely. Workload Identity is clean. Fastest K8s version availability. AKS: tightest Azure integration (Managed Identity, Azure CNI, AKS-native monitoring). All three are production-grade. Choose based on your cloud — don't run GKE in an AWS-primary org without a strong reason."

**Q: How has your approach to secrets management evolved across your career?**
> "Three stages. Cybage: Azure DevOps Library — variable groups and secure files. Works but scoped to CI/CD, not Kubernetes-native. At Compliance Innovation I inherited self-managed Vault — powerful but ops overhead is real, single point of failure. I migrated that to AWS SSM + ESO — zero operational overhead, K8s-native sync, audit via CloudTrail. The pattern I use now: secrets live in the cloud provider's managed store (SSM, Secrets Manager), ESO syncs them into K8s Secrets on a configurable interval. Application reads a normal K8s Secret — no SDK changes, no cloud SDK dependency in app code."

**Q: What's the most complex K8s thing you've done?**
> Use the Vault→SSM ESO migration story OR the Indicios Docker Compose → Helm + Pulumi Operator story. Both have architectural depth.

**Q: Walk me through your CI/CD philosophy.**
> "Three principles. First, every pipeline runs on a clean environment — no artifacts from previous builds. Second, fail fast — lint and test before building a Docker image, quality gate before push. Third, environments are identical except for config — same image, same Helm chart, different values. What I specifically look for in a pipeline: test coverage gate, container image scanning, OIDC auth (no long-lived credentials), and deploy step that waits for rollout completion — not just 'helm upgrade returned 0'."

**Q: You have CKA. What's the hardest part of the exam?**
> "Time pressure. 17 tasks in 2 hours on a live cluster. The technical content is not the hard part — it's that you need muscle memory on imperative kubectl commands: `kubectl run`, `kubectl expose`, `kubectl create` with all the flags. No time to check docs for basic syntax. The topics that need most practice: NetworkPolicy (common exam topic, requires understanding pod selectors and namespace selectors precisely), ETCD backup and restore (always in the exam), and kubeadm cluster upgrades (specific version upgrade procedure). I practiced on killer.sh for the time pressure simulation."

---

# CERTIFICATION DEEP DIVES

## CKA — Certified Kubernetes Administrator

**Cert Number:** LF-ig7ixm4i9p (The Linux Foundation)

**What it covers (topics to know for interviews):**
| Topic | What they ask |
|-------|--------------|
| Cluster architecture | Control plane components (API server, etcd, scheduler, controller manager) |
| RBAC | Role, ClusterRole, RoleBinding, ServiceAccount |
| Networking | NetworkPolicy (ingress/egress rules), Service types (ClusterIP/NodePort/LoadBalancer), DNS |
| Storage | PV, PVC, StorageClass, dynamic provisioning |
| Workloads | Deployment, DaemonSet, StatefulSet, Job, CronJob |
| Troubleshooting | `kubectl describe`, `kubectl logs`, check node conditions |
| Cluster upgrade | kubeadm upgrade sequence |
| ETCD | `etcdctl snapshot save/restore` |

**Interview answer for "what's hardest in CKA":**
> "NetworkPolicy. The selector syntax is precise — namespaceSelector and podSelector can be combined with AND or OR semantics depending on how you write the YAML, and getting it wrong means silent drops. Also ETCD backup/restore because the environment variables for etcdctl (ETCDCTL_API, cert paths) are easy to get wrong under time pressure."

## AZ-204 — Azure Developer Associate

**Cert Number:** 1453-0384

**What it covers (relevant to your work):**
- Azure App Service (PaaS web hosting)
- Azure Functions (serverless)
- Azure Container Instances (ACI)
- Azure Container Registry (ACR)
- Azure Storage (blobs, queues, tables)
- Azure Key Vault (secrets, certs, keys)
- Azure Service Bus (messaging)
- CosmosDB (NoSQL)
- Azure Active Directory (authentication, managed identity)

**If asked "why AZ-204 as a DevOps engineer?":**
> "AZ-204 gave me the developer's perspective on Azure services — understanding what App Service deployment slots do, how ACR authentication works, how Managed Identity flows from application code perspective. That context makes me a better DevOps engineer — I understand what the application actually needs from the infrastructure I build."

## AZ-900 — Azure Fundamentals

**Cert Number:** I324-1514

Foundational. Covers Azure services overview, pricing, compliance, SLAs. Rarely asked about in senior interviews. Just mention it if asked about certifications list.

---

# EDUCATION

## PG Diploma in Advanced Computing — CDAC ACTS Pune (2020–2021)

**What is CDAC?** Centre for Development of Advanced Computing. Government of India institution. The PG Diploma in Advanced Computing (PGDAC) is a highly competitive 6-month intensive program — ~60-70 hrs/week. Covers algorithms, OS, networking, databases, Java EE, .NET, cloud basics. Very respected by Indian IT companies as a signal of strong fundamentals. Admission via C-CAT exam.

**If asked about it:**
> "CDAC ACTS Pune is a government institution with one of India's most intensive computing programs. 6-month full-time program covering everything from OS internals and networking to enterprise Java and .NET. It's how I built strong fundamentals after my engineering degree. It's how I transitioned from a generalist engineer into specialized software/DevOps roles."

---

# NUMBERS TO QUOTE (all projects)

| Project | Numbers |
|---------|---------|
| TokenTide | 3 environments (Dev/Test/Prod), EKS + Minikube |
| Dgraph | 3 Pulumi stacks, StatefulSet with PVCs per environment |
| Neo4j | Daily backups, **30-day** S3 retention, **~30 min RTO** |
| Vault → SSM | ESO refresh: **1 hour**, zero downtime migration, Vault decommissioned |
| GKE | Multiple apps onboarded, same Helm chart as EKS |
| Victra DB | **3 environments**, **zero manual** production deployments, 1-month parallel validation |
| Mobile CI/CD | **~30 min** pipeline, Google Play + App Store automated |
| MIS Dashboard | 4+ microservices, 1 GraphQL gateway, Terraform (AKS + MySQL + SQL Server + ACR) |
| DevOps Lab | **~17 min** infra apply, **~10-12 min** destroy, **$132/month** saved (no NAT) |

---

# TRAP QUESTIONS — WATCH OUT

**"You worked at a startup (TokenTide) for only 6 months — why so short?"**
> "I'm still there — current role as of today. Nov 2025 to present."

**"You've used a lot of different tools — are you a specialist or a generalist?"**
> "Kubernetes specialist, cloud generalist. The underlying K8s concepts are the same across EKS/GKE/AKS. I can go deep on Kubernetes architecture, networking, security, operators. The cloud-specific glue (IAM, storage classes, ingress controllers) I pick up quickly because the pattern is the same. My specialization is cloud-native platform engineering — the intersection of K8s, IaC, CI/CD, and observability."

**"Have you ever managed production incidents?"**
> "Yes — the most memorable was at Compliance Innovation when Vault went down unexpectedly during business hours. Every app that fetched secrets at startup couldn't boot. We had no auto-unseal configured. I unsealed it manually from CLI, apps recovered, but the incident made the business case for migrating to SSM obvious. Within two weeks the migration plan was approved. The incident created the urgency."

**"You mention Pulumi a lot — why not just Terraform? Everyone knows Terraform."**
> "Terraform for standard infra, absolutely — I've used both professionally. The Pulumi choice at Compliance Innovation was specific: the Pulumi Operator gave us GitOps for infrastructure changes without a separate CI step. Push to Git → operator picks it up → pulumi up runs in cluster. Also, the deployment ordering logic (wait for database readiness before deploying dependent services) was cleaner in TypeScript than in Terraform depends_on. I'm not anti-Terraform — I use it for AKS, MySQL, SQL Server infra at Cybage. It's the right tool for that. Pulumi for orchestration and conditional logic."

**"You mentioned SonarQube in your skills — tell me about it."**
> "SonarQube is a code quality and static analysis platform. It analyzes source code for bugs (null pointer risks, off-by-one), vulnerabilities (SQL injection patterns, hardcoded credentials), code smells (too-long methods, duplicated code), and test coverage percentage. In CI pipelines, SonarQube runs as a scan step and reports to a Quality Gate — a configurable threshold. If code coverage drops below X%, or new critical vulnerabilities are introduced, the Quality Gate fails and the pipeline stops. No deployment with a failing gate. I integrated it into GitHub Actions at Compliance Innovation via the SonarQube Maven/Gradle plugin for Java services."

---

# ONE-LINE PROJECT SUMMARIES

When they ask "tell me about your projects" — pick one and expand:

- **TokenTide:** Migrated production services from NGINX Ingress to EKS with Gateway API, deployed Dgraph across 3 environments using Pulumi IaC, built full Grafana observability.
- **OnyxPlus/Indicios:** Migrated entire application stack from Docker Compose to Helm on EKS using Pulumi Operator for GitOps-style IaC, with automated Neo4j backups to S3.
- **Simplici/Liquidity:** Migrated secrets from self-managed Vault to AWS SSM with External Secrets Operator, built GitHub Actions CI/CD, onboarded apps to GKE with standardized Helm patterns.
- **Victra:** Database DevOps for Verizon using SSDT and Azure DevOps — fully automated SQL Server schema changes from Git to production, zero manual DBA deployments.
- **MIS Dashboard:** Microservices on AKS with Terraform IaC, SpringBoot services, GraphQL API gateway via HotChocolate, Flyway DB migrations, GitHub Actions CI/CD.
- **Mobile CI/CD:** Android + iOS automated pipelines via Azure DevOps — Gradle/Xcode build, signing, submission to Google Play and App Store in ~30 minutes.
- **DevOps Lab (this project):** Built complete DevOps platform on EKS with OpenTofu, Traefik Gateway API, cert-manager, Pod Identity, 4-workflow GitHub Actions CI/CD.
