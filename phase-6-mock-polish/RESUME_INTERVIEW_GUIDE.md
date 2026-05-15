# Resume Projects — Interview Guide

All projects from your resume with STAR stories, common Q&A, and numbers to quote.
Covers: TokenTide, Compliance Innovation (OnyxPlus/Indicios + Simplici/Liquidity), Cybage (Victra/MIS Dashboard).

---

## How to Use This Guide

1. Every section has a **context paragraph** — read before the interview, not during.
2. **STAR stories** are pre-built — memorize the arc, not word-for-word.
3. **Q&A** covers what interviewers actually ask — have these loaded in memory.
4. **Numbers** — always have at least 2-3 numbers per project ready.

---

## Company 1: TokenTide (Nov 2025 – Present)

### Context
Remote position. Production services running on NGINX Ingress, needed migration to EKS. Dgraph (graph database) deployed across three environments using Pulumi. Grafana dashboards built for full observability.

---

### STAR Story 1 — NGINX to EKS Migration

**S:** Production services at TokenTide were running on NGINX Ingress Controller on Minikube — not scalable for prod traffic, no proper cluster lifecycle management.

**T:** Migrate to AWS EKS with proper ingress control and improve routing flexibility without downtime.

**A:** Evaluated NGINX Ingress (being retired in 2026) vs Traefik with Gateway API. Chose Traefik + Gateway API — modern standard, role separation for multi-tenant routing. Set up EKS cluster, migrated services one by one using blue-green cutover at DNS level. Updated all Ingress manifests to HTTPRoute resources.

**R:** All production services running on EKS. Routing control improved — each team manages their own HTTPRoute without infra team involvement. Zero downtime migration.

**Numbers:** 3 environments (Dev/Test/Prod), Gateway API HTTPRoutes replacing NGINX annotations.

---

### STAR Story 2 — Dgraph Multi-Environment with Pulumi

**S:** Dgraph (distributed graph database) needed consistent deployment across Dev, Test, and Prod. Manual deployments were causing environment drift — Prod had config that Dev didn't have.

**T:** Deploy Dgraph across all 3 environments with full parity using IaC so any config change applies everywhere.

**A:** Used Pulumi (TypeScript) to define Dgraph deployment as code. Single stack definition with environment-specific config (replicas, storage size, resource limits) passed via Pulumi config. Deployed as StatefulSet with persistent volumes. Same code, different `pulumi.Config` values per environment.

**R:** Zero environment drift. Dev, Test, Prod all deploy from the same Pulumi code. Any Dgraph config change goes through code review before hitting Prod.

**Numbers:** 3 environments, Pulumi IaC, StatefulSet with PVCs.

---

### STAR Story 3 — Grafana Observability Stack

**S:** No visibility into what was running — no dashboards, no alerts, issues discovered by users not by the team.

**T:** Build end-to-end observability covering logs and infrastructure metrics for all three environments.

**A:** Deployed kube-prometheus-stack (Prometheus + Grafana + Alertmanager) per environment. Built dashboards using RED method for services — request rate, error rate, p99 latency. Added infrastructure panels using USE method — node CPU, memory, disk. Connected Loki for log aggregation. Set up Alertmanager routing to Slack for error rate spikes.

**R:** Full observability across Dev/Test/Prod. Team catches issues before users do. Dashboard used daily for release health checks.

---

### Q&A — TokenTide

**Q: Why did you migrate from NGINX Ingress to EKS?**
> "Two reasons. First, NGINX Ingress Controller maintenance ended March 2026 — we needed to move to a supported solution. Second, EKS gives us proper cluster lifecycle management — node upgrades, add-on management, IAM integration — that Minikube doesn't provide for production workloads."

**Q: What is Dgraph and why is it a graph database?**
> "Dgraph is a distributed graph database — instead of tables with rows and columns, data is stored as nodes and edges. Perfect for relationship-heavy data — social graphs, knowledge graphs, recommendation engines. It uses GraphQL natively as its query language. We used it because the application's data model was heavily relational — representing entities and their connections."

**Q: Why Pulumi over Terraform for Dgraph?**
> "Dgraph deployment had conditional logic — different replica counts, different storage classes, different resource limits per environment. Terraform's HCL is declarative and handles simple conditionals but gets messy with complex logic. Pulumi lets you write TypeScript — real if/else, loops, functions, classes. We could express the environment-specific config cleanly without HCL workarounds."

**Q: What Grafana dashboards did you build? Walk me through one.**
> "Built RED method dashboards per service — request rate (how many req/sec), error rate (% returning 5xx), and duration (p99 latency via histogram_quantile). Also infrastructure USE dashboards — node CPU utilization, memory saturation, disk. Each dashboard had namespace/service variables as dropdowns so the same dashboard worked for all three environments."

---

## Company 2: Compliance Innovation Pvt Ltd (Jul 2024 – Nov 2025)

### Projects
- **OnyxPlus / Indicios (Telos)** — Docker Compose → Helm migration, Pulumi on EKS/Minikube, Neo4j with S3 backups
- **Simplici / Liquidity** — GitHub Actions CI/CD, Vault → SSM migration, ESO, GKE onboarding, Cloudflare DNS

---

### STAR Story 1 — Docker Compose to Helm Migration (OnyxPlus/Indicios)

**S:** Indicios application stack was running on Docker Compose — no K8s, no scalability, no rolling deployments. Team was manually docker-compose up/down on VMs.

**T:** Migrate entire stack to Kubernetes-native deployment using Helm charts, deployed via Pulumi for IaC consistency.

**A:** Audited the Docker Compose file — identified all services, volumes, networks, environment variables. Created Helm chart per service — Deployment, Service, ConfigMap for non-sensitive config, Secrets for sensitive values. Used Pulumi to orchestrate Helm chart installation in the right order (databases first, then dependent services). Added readiness probes to each service so Pulumi knew when each was healthy before proceeding to dependents.

**R:** Full application stack running on EKS. Rolling deployments work — no more downtime during updates. Infrastructure is code — any developer can spin up the full stack with one `pulumi up`.

**Numbers:** Multiple services migrated, Helm charts per service, readiness probes for deployment ordering.

---

### STAR Story 2 — Neo4j S3 Backup (OnyxPlus/Indicios)

**S:** Neo4j database running in Kubernetes with no backup strategy. Any persistent volume failure = data loss.

**T:** Implement automated backup workflow that stores Neo4j dumps in S3 for retention and recovery.

**A:** Created a Kubernetes CronJob that runs daily using the Neo4j admin shell (`neo4j-admin dump`). CronJob uses a ServiceAccount with Pod Identity mapped to an IAM role with S3 write access. Backup filename includes timestamp — `neo4j-backup-2026-05-15.dump`. S3 lifecycle policy deletes backups older than 30 days. Tested restore by restoring a backup to a staging cluster.

**R:** Daily automated backups to S3. Recovery tested and documented — RTO of ~30 minutes for a full restore. 30-day retention window.

**Numbers:** Daily backups, 30-day retention, ~30 min RTO, S3 lifecycle policy.

---

### STAR Story 3 — Vault to AWS SSM Migration (Simplici/Liquidity)

**S:** Team was running self-managed HashiCorp Vault on a VM. High operational overhead — manual unsealing after restarts, manual token rotation, on-call burden when Vault went down. Also a single point of failure for all application secrets.

**T:** Migrate all application secrets from Vault to AWS Systems Manager Parameter Store. Zero downtime, no secrets exposed during migration.

**A:** Audited all secrets in Vault — categorized by sensitivity (plain text vs encrypted at rest). Created matching parameters in AWS SSM Parameter Store using SecureString type (KMS-encrypted). Implemented External Secrets Operator (ESO) to sync SSM parameters into K8s Secrets on a 1-hour refresh interval. Migrated services one at a time — updated each app to read from ESO-synced K8s Secret, verified it worked, then deleted the Vault entry. Decommissioned Vault after all services migrated.

**R:** Zero Vault operational burden. Secrets managed via AWS — no manual unsealing, no token rotation, native CloudTrail audit log. ESO refreshes secrets automatically — any SSM update reflects in cluster within 1 hour without pod restart.

**Numbers:** Multiple services migrated, 1-hour refresh interval, zero downtime, Vault fully decommissioned.

---

### STAR Story 4 — GKE Onboarding with Standardized Patterns (Simplici/Liquidity)

**S:** Company expanding from AWS (EKS) to GCP (GKE) for a client requirement. No established pattern for GKE deployments — risk of inconsistency between clusters.

**T:** Onboard multiple applications to GKE with the same deployment standards used on EKS.

**A:** Created a reusable Helm chart template — standardized Deployment structure (resource requests/limits, probes, anti-affinity), Service, HPA, and optional Ingress. Used Workload Identity (GKE equivalent of Pod Identity) for applications needing GCP resource access. Set up GitHub Actions workflow with GKE-specific auth (Workload Identity Federation, same OIDC pattern as AWS). Documented the pattern so other engineers could onboard new apps without tribal knowledge.

**R:** Multiple applications onboarded to GKE with consistent patterns. Same Helm charts work on both EKS and GKE — only values differ. New app onboarding time reduced significantly.

---

### Q&A — Compliance Innovation

**Q: Walk me through the Vault to SSM migration. Why SSM over Vault?**
> "Self-managed Vault has real operational overhead — it needs unsealing after every restart, token management, HA setup to avoid SPOF. For a small team, that's a burden that doesn't deliver product value. AWS SSM Parameter Store is fully managed — no infrastructure to run, KMS encryption by default, CloudTrail audit logging built in, and natively integrates with IAM. Migration was done service by service — audit Vault, create matching SSM parameters as SecureString, deploy ESO to sync them into K8s Secrets, migrate one service, verify, delete Vault entry. Full migration with zero downtime."

**Q: What is External Secrets Operator and how did you configure it?**
> "ESO is a Kubernetes controller that syncs secrets from external secret managers into K8s Secrets automatically. You define a ClusterSecretStore pointing at AWS SSM, then ExternalSecret CRs that say 'fetch this SSM parameter, create this K8s Secret'. ESO polls on a configurable interval — we used 1 hour. The application reads a normal K8s Secret and doesn't know anything about SSM. ESO handles auth via Pod Identity — no static credentials in the controller."

**Q: What is the Pulumi Operator?**
> "The Pulumi Operator is a Kubernetes operator that runs Pulumi programs inside the cluster. Instead of running `pulumi up` from your laptop or CI, you define a Stack CR in Kubernetes pointing to your Pulumi program in Git. The operator watches for changes — when you commit a change to your Pulumi program, the operator picks it up and runs the update automatically. It's GitOps for infrastructure — Git is source of truth, operator reconciles actual state."

**Q: How did you manage Cloudflare DNS for production workloads?**
> "Cloudflare was used as both DNS provider and reverse proxy. For each service, we created DNS records in Cloudflare pointing to the load balancer or ingress IP. Cloudflare's proxy mode (orange cloud) adds DDoS protection and caching in front. For internal services, DNS-only mode (grey cloud) — direct routing. DNS changes were managed via Terraform Cloudflare provider — no manual Cloudflare UI changes."

**Q: What is Neo4j and how does it differ from PostgreSQL?**
> "Neo4j is a graph database — data stored as nodes, relationships, and properties. PostgreSQL is relational — tables and foreign keys. For relationship-heavy queries, Neo4j is dramatically faster — a 3-hop relationship query that takes seconds in SQL with JOINs takes milliseconds in Neo4j's Cypher query language. We used it for the Indicios application because the data model was a complex graph — entities connected by typed relationships, and queries traversed those relationships."

**Q: How did you handle Neo4j backups and what was your RTO?**
> "CronJob ran daily using `neo4j-admin dump` — outputs a binary dump of the entire database. Uploaded to S3 with timestamp in filename, 30-day lifecycle policy. Restore process: spin up new Neo4j pod, copy dump from S3, run `neo4j-admin load`. Tested in staging — full restore took about 30 minutes depending on database size. That was our documented RTO."

---

## Company 3: Cybage Software Pvt Ltd (Jul 2021 – Jul 2024)

### Projects
- **Victra (Verizon)** — Database DevOps with SSDT via Azure DevOps, Android/iOS CI/CD
- **MIS Dashboard** — Microservices on AKS, SpringBoot + GraphQL Gateway, Terraform + GitHub Actions

---

### STAR Story 1 — Database DevOps for Victra (Verizon)

**S:** Victra (Verizon's largest retail partner) had manual SQL Server database deployments — DBAs running scripts by hand in production. High risk of human error, no audit trail, no rollback mechanism.

**T:** Automate end-to-end database builds and production deployments using Azure DevOps. Zero manual steps in the pipeline.

**A:** Implemented Database DevOps using SSDT (SQL Server Data Tools) — database schema defined as Visual Studio project, versioned in Git like application code. Built Azure DevOps pipeline: compile SSDT project → generate .dacpac artifact → use SqlPackage to compare and deploy to target SQL Server (Dev/Staging/Prod). Added pre-deployment scripts for data migrations and post-deployment scripts for verification. Integrated with change management — pipeline blocked on Prod unless change ticket approved.

**R:** Zero manual database deployments for Victra. Every schema change goes through Git PR → code review → automated pipeline → Prod. Full audit trail in Azure DevOps. Rollback via previous .dacpac artifact.

**Numbers:** Full Azure DevOps pipeline, 3 environments (Dev/Staging/Prod), zero manual steps.

---

### STAR Story 2 — MIS Dashboard Microservices on AKS

**S:** Client needed a Management Information System dashboard aggregating data from multiple backend services — inventory, sales, HR, finance. Each service had different APIs and data formats.

**T:** Build microservices architecture on AKS with a unified API layer, automated provisioning, and CI/CD.

**A:** Designed microservices — each domain (inventory, sales, etc.) as independent SpringBoot service. Implemented GraphQL as API gateway using ASP.NET Core + HotChocolate library — single `/graphql` endpoint, schema stitching aggregates data from all microservices. Frontend (React) sends one GraphQL query, gateway fans out to relevant services, combines responses. Infrastructure provisioned via Terraform (AKS cluster, Azure MySQL, Azure SQL Server, ACR). GitHub Actions CI/CD — build Docker image, push to ACR, helm upgrade on AKS. Used Flyway for database schema migrations as part of the pipeline.

**R:** MIS Dashboard live on AKS. Single GraphQL query replaces what used to be 5 separate REST calls from frontend. Infrastructure fully automated — new environment setup in minutes via Terraform.

**Numbers:** Multiple microservices, 1 GraphQL gateway, Terraform for AKS + MySQL + SQL Server + ACR, Flyway migrations.

---

### STAR Story 3 — Android + iOS CI/CD (Victra)

**S:** Mobile apps (Android and iOS) for Victra were being manually built and submitted to stores — error-prone, took full days, blocked on specific developer machines.

**T:** Fully automated CI/CD pipeline for both Android (Google Play) and iOS (App Store Connect) via Azure DevOps.

**A:** Android pipeline: Azure DevOps agent with Android SDK, Gradle build, sign with keystore (secret stored in Azure DevOps Library), upload to Google Play internal track via Google Play Developer API. iOS pipeline: macOS build agent (Azure DevOps self-hosted or hosted macOS), Xcode build, sign with provisioning profile and certificate (stored as secure files in Azure DevOps Library), upload to App Store Connect via Fastlane. Separate pipelines for debug (every commit) and release (tag-based trigger).

**R:** Both Android and iOS pipelines fully automated. Dev team pushes code → 30 minutes later → build in Google Play internal track or TestFlight. Release builds triggered by Git tag — no manual store uploads ever.

**Numbers:** Azure DevOps, ~30 min build time, Google Play + App Store Connect automated.

---

### Q&A — Cybage

**Q: What is SSDT and Database DevOps? Explain it simply.**
> "SSDT is SQL Server Data Tools — it lets you define your SQL Server database schema as a Visual Studio project stored in Git, just like application code. Instead of running ALTER TABLE scripts manually, you make changes in the SSDT project, commit, and a pipeline compares your desired schema against the live database and generates the diff automatically. The tool is SqlPackage — it produces a .dacpac (database schema snapshot) and deploys only the delta. Database changes go through the same PR + review + automated deploy process as application code."

**Q: What is GraphQL and why did you use it as an API Gateway?**
> "GraphQL is a query language for APIs where the client specifies exactly what data it needs — no overfetching, no underfetching. As an API gateway, we used HotChocolate (a .NET GraphQL server) with schema stitching — it combines the schemas from multiple microservices into one unified GraphQL schema. The frontend sends one query to the gateway, the gateway fans out requests to the relevant services, combines the results, and returns exactly what was asked for. This replaced 5 separate REST calls from the frontend with a single request."

**Q: What is Flyway and how does database migration work?**
> "Flyway is a database migration tool. You write migration scripts named with a version prefix — V1__create_users.sql, V2__add_email_column.sql. Flyway maintains a schema_history table in the database tracking which migrations have run. When you deploy, Flyway runs any migrations that haven't been applied yet, in version order. This is idempotent and versioned — you always know exactly what state the database is in. We ran Flyway as part of the CI/CD pipeline before deploying the application, so schema changes always preceded the code that depends on them."

**Q: What Azure resources did you provision with Terraform for MIS Dashboard?**
> "AKS cluster — node pool sizes, system + user node pools. Azure MySQL for relational data. Azure SQL Server for the legacy data warehouse. Azure Container Registry for Docker images. Azure Load Balancer (created automatically by AKS). App Service for a few non-containerized services. All in one Terraform workspace, separate tfvars files per environment."

**Q: How did you handle iOS signing certificates in Azure DevOps?**
> "iOS requires two secrets: a signing certificate (.p12 file) and a provisioning profile (.mobileprovision file). Stored both as Secure Files in Azure DevOps Library — encrypted at rest, only accessible to authorized pipelines. Pipeline downloads them to the build agent at runtime, installs in the macOS keychain, Xcode picks them up. After build, the agent cleans up — secrets never persist on the agent. Certificates were rotated annually and the Azure DevOps file updated without touching pipeline YAML."

**Q: What was your biggest challenge at Cybage?**
> "Database DevOps for Victra. The hardest part wasn't the technical implementation — it was getting the DBA team to trust the automated pipeline for production. DBAs had been doing manual deployments for years. We solved it by running the pipeline in parallel with manual deployments for the first month — same changes, both paths. Zero discrepancies in a month built enough confidence that the team fully switched. The human change management was harder than the technical work."

---

## Cross-Project Questions

**Q: You've worked with Pulumi AND Terraform. When do you choose which?**
> "Terraform for straightforward cloud infrastructure — VPCs, RDS, IAM, standard resources with simple config. HCL is readable and the community ecosystem is huge. Pulumi when you need real programming — at Cybage for simple Azure infra I used Terraform. At Compliance Innovation for Dgraph with complex conditional logic per environment, and at TokenTide for orchestrating Helm charts with deployment ordering, I used Pulumi TypeScript. The rule: if you find yourself writing complex HCL count/for_each hacks, switch to Pulumi."

**Q: You've worked on EKS, GKE, and AKS. What are the key differences?**
> "EKS (AWS): most mature, best IAM integration via Pod Identity, most enterprise adoption. Node management is explicit — you manage node groups. Karpenter is the modern node autoscaler. GKE (GCP): Autopilot mode is excellent — Google manages nodes for you. Workload Identity for IAM. Best managed experience out of the three. AKS (Azure): tightest Azure integration, Managed Identity for pod auth. All three use the same Kubernetes API — your Helm charts and manifests work on all three, only the cloud-specific resources (IAM, storage classes) differ."

**Q: Walk me through a CI/CD pipeline you're proud of.**
> Use the Victra Database DevOps story — it has the most impact (Verizon scale, real production risk, human change management challenge).

**Q: How did you handle secrets management across your career?**
> "Three different approaches across my roles. At Cybage — Azure DevOps Library secure files and variable groups, secrets injected at pipeline runtime. At Compliance Innovation — started with self-managed HashiCorp Vault, migrated to AWS SSM Parameter Store + External Secrets Operator for K8s syncing. Currently best practice I use is ESO with AWS SSM — secrets stored centrally in SSM, ESO syncs to K8s Secrets on a refresh interval, application reads normal K8s Secret. Actual secret values never in Git, never hardcoded."

**Q: You have CKA certification. What's the hardest CKA topic?**
> "Networking — specifically configuring NetworkPolicies correctly and understanding kube-proxy iptables rules. Also the time pressure is real — 17 questions in 2 hours, mostly hands-on kubectl. The trick is muscle memory on kubectl commands: `kubectl run`, `kubectl expose`, `kubectl rollout`, imperative commands for speed. ETCD backup/restore was the topic I practiced most because it's always in the exam."

---

## Numbers to Have Ready (All Projects)

| Project | Numbers |
|---------|---------|
| TokenTide | 3 environments (Dev/Test/Prod), EKS cluster, Grafana dashboards for all 3 |
| OnyxPlus/Indicios | Docker Compose → Helm migration, Neo4j daily backups, 30-day S3 retention, ~30 min RTO |
| Simplici/Liquidity | Vault → SSM migration, ESO 1-hour refresh, zero downtime, multiple services |
| Victra | Verizon scale, zero manual DB deployments, 3 environments, Azure DevOps |
| MIS Dashboard | Multiple microservices, 1 GraphQL gateway, Terraform + AKS + MySQL + SQL Server |
| Mobile CI/CD | Android + iOS, ~30 min pipeline, Google Play + App Store automated |

---

## One-Line Project Summaries (for when interviewer asks "tell me about your projects")

- **OnyxPlus/Indicios:** "Migrated a full application stack from Docker Compose to Helm on EKS using Pulumi IaC, with automated Neo4j backups to S3."
- **Simplici/Liquidity:** "Migrated secrets from self-managed Vault to AWS SSM with External Secrets Operator, and onboarded applications to GKE with standardized Helm patterns."
- **Victra:** "Implemented Database DevOps for Verizon using SSDT and Azure DevOps — fully automated SQL Server schema changes from Git to production."
- **MIS Dashboard:** "Built a microservices dashboard on AKS with GraphQL as API gateway, Terraform infrastructure, and GitHub Actions CI/CD."
- **DevOps Lab (this project):** "Built a complete DevOps platform on EKS with OpenTofu, Traefik Gateway API, cert-manager, Pod Identity, and a four-workflow GitHub Actions CI/CD pipeline."
