# Project Implementation Interview Guide

How to talk about this project in interviews. Every component — what it is, why we chose it, how it works, numbers to quote, challenges faced.

---

## 30-Second Project Pitch

> "I built a complete DevOps platform on AWS — EKS cluster provisioned with OpenTofu, Traefik as ingress controller using the Gateway API standard, cert-manager for automated TLS, and a four-workflow GitHub Actions CI/CD pipeline. The platform hosts a demo app that uses Pod Identity to access S3 without any hardcoded credentials. I removed all VPC Interface Endpoints to save $87/month and rewrote the destroy workflow to fix a persistent DependencyViolation root cause that had been failing for six runs."

---

## Architecture Diagram

```
GitHub Repo
    │
    ├── push to iac/**  →  infra-apply.yaml (ubuntu-latest, static creds)
    │                         └── OpenTofu apply → AWS
    │
    ├── manual trigger  →  bootstrap.yaml (ubuntu-latest, OIDC)
    │                         └── Traefik + cert-manager on EKS
    │
    ├── push to app/**  →  ci.yaml (ubuntu-latest, OIDC for deploy)
    │                         └── helm lint → helm upgrade s3-lister
    │
    └── manual trigger  →  destroy.yaml (ubuntu-latest, static creds)
                              └── Helm uninstall → tofu destroy

AWS (us-east-1):
┌─────────────────────────────────────────────────────────┐
│  VPC (custom, 10.0.0.0/16)                              │
│  ┌──────────────────┐  ┌──────────────────┐            │
│  │ Public Subnet AZ-a│  │ Public Subnet AZ-b│           │
│  │  EKS Node (t3.med)│  │  EKS Node (t3.med)│          │
│  │  [Traefik NLB]   │  │                  │            │
│  └──────────────────┘  └──────────────────┘            │
│  S3 Gateway Endpoint (free, S3 traffic stays internal)  │
└─────────────────────────────────────────────────────────┘

EKS Cluster (v1.33):
  Namespaces: traefik / cert-manager / default
  Add-ons: vpc-cni, kube-proxy, coredns, ebs-csi, pod-identity-agent, metrics-server
  
  traefik namespace:
    Traefik → NLB → handles all ingress via Gateway API
  
  cert-manager namespace:
    cert-manager → TLS automation, images from ECR
  
  default namespace:
    s3-lister Deployment
      init container (aws-cli) → lists S3 buckets → writes HTML
      nginx container → serves the HTML
    ServiceAccount → Pod Identity → IAM role → S3 read access
    HTTPRoute → routes /s3-lister/* → s3-lister Service
```

---

## Component Deep Dives

### 1. VPC + Networking

**What:** Custom VPC in us-east-1. 2 public + 2 private subnets across 2 AZs. No NAT Gateway.

**Key decision — nodes in public subnets:**
> "We put EKS nodes in public subnets with public IPs. They reach ECR, STS, EKS-auth via the internet through the IGW directly — no NAT Gateway needed. This saves ~$45/month and removes a single point of failure."

**Key decision — no VPC Interface Endpoints:**
> "VPC Interface Endpoints for ECR, STS, EKS-auth cost ~$87/month and are unnecessary when nodes have public IPs. We only keep the S3 Gateway Endpoint, which is free and routes S3 traffic internally."

**Numbers:**
- NAT Gateway saved: $45/month
- Interface Endpoints saved: $87/month
- Total networking savings: ~$132/month
- Only cost: S3 Gateway Endpoint — $0 (free)

---

### 2. EKS Cluster

**What:** EKS v1.33, 2× t3.medium nodes (managed node group).

**Add-ons installed:**
| Add-on | Purpose |
|--------|---------|
| vpc-cni | Pod networking — each pod gets a real VPC IP (prefix delegation enabled) |
| kube-proxy | Service IP routing via iptables |
| coredns | In-cluster DNS |
| ebs-csi | EBS persistent volumes |
| pod-identity-agent | AWS Pod Identity (IAM for pods) |
| metrics-server | HPA + `kubectl top` support |

**Node sizing:** t3.medium (2 vCPU, 4GB) — enough for Traefik + cert-manager + demo app.

**node_min: 0** — cluster can scale to zero nodes when idle (saves money).

---

### 3. OpenTofu (Not Terraform)

**Why not Terraform?**
> "HashiCorp changed Terraform's license to BSL (Business Source License) in 2023 — it's no longer truly open source. OpenTofu is the Linux Foundation fork, maintained by the community, 100% open source under MPL. It's API-compatible with Terraform. For a learning project I want to use tools aligned with open source values."

**IaC structure:**
```
iac/
├── envs/dev/
│   ├── main.tf       → VPC module + EKS module + ECR + IAM + S3 + OIDC
│   ├── dev.tfvars    → region, cluster name, instance type, node counts
│   ├── outputs.tf    → ECR registry, cluster name, role ARNs
│   └── versions.tf   → S3 backend config + provider versions
└── modules/
    ├── vpc/          → VPC, subnets, S3 gateway endpoint
    └── eks/          → EKS cluster, managed node group, add-ons, Pod Identity
```

**Apply time:** ~17 minutes (with `-parallelism=20` — was ~24 min with default 10).

**Why `-parallelism=20`:** ECR repos, IAM roles, S3 bucket have no inter-dependencies. Default parallelism of 10 was serializing independent resources.

---

### 4. IAM — Pod Identity vs IRSA

**What is Pod Identity?**
EKS feature that lets pods assume IAM roles without OIDC federation. Simpler than IRSA.

**IRSA (old way):**
```
1. Create OIDC provider in IAM
2. Create IAM role with trust policy referencing OIDC provider
3. Annotate ServiceAccount with role ARN
4. Pod assumes role via projected service account token + OIDC
5. Complex trust policy with exact namespace/SA name match
```

**Pod Identity (our way):**
```
1. Create IAM role (simple trust policy — just EKS Pod Identity service)
2. Create Pod Identity Association: "ServiceAccount X in namespace Y → IAM role Z"
3. Pod Identity Agent (DaemonSet) injects credentials automatically
4. No annotations needed on ServiceAccount
```

**Why Pod Identity:**
> "Pod Identity is simpler — no OIDC trust policy to debug, no annotation on the ServiceAccount, and Pod Identity Association is a first-class AWS resource managed by OpenTofu. Role ARNs don't change when you recreate the cluster, which means no manual updates."

**We still use OIDC for GitHub Actions** — OIDC is the standard for CI/CD systems that need temporary credentials without long-lived keys. That's a different use case.

---

### 5. ECR + Pull-Through Cache

**What:** ECR pull-through cache for Docker Hub. Instead of pods pulling from `docker.io/library/nginx`, they pull from `<account>.dkr.ecr.us-east-1.amazonaws.com/docker-hub/library/nginx`.

**Why:**
- Docker Hub rate limits: 100 pulls/6h for anonymous, 200/6h for free account
- In a cluster with many nodes pulling many images, you hit limits fast
- ECR pull-through cache = Docker Hub mirror in your own ECR
- First pull goes to Docker Hub, subsequent pulls served from ECR cache
- No more rate limit issues

**For cert-manager images (quay.io):**
quay.io doesn't support ECR pull-through cache. So bootstrap.yaml manually:
1. Pulls 4 images from quay.io (runner has internet)
2. Pushes to `ECR/quay-io/jetstack/*`
3. Helm install references ECR images

---

### 6. Traefik + Gateway API

**Why Traefik over NGINX Ingress?**
> "NGINX Ingress is being retired — maintenance ended March 2026, K8s 1.36 removes it. Traefik has first-class Gateway API support. We're already using the modern standard."

**Why Gateway API over Ingress?**
> "Gateway API is the official K8s replacement for Ingress. It has role separation — GatewayClass (infra team), Gateway (platform team), HTTPRoute (dev team). Better multi-tenancy, more expressive routing, and it's now mandatory as Ingress is deprecated."

**Our setup:**
```yaml
GatewayClass: traefik      (managed by Traefik)
Gateway: traefik-gateway   (one gateway, allows routes from all namespaces)
HTTPRoute: s3-lister       (routes /s3-lister/* to s3-lister service)
```

**NLB:** Traefik creates an AWS Network Load Balancer (in-tree cloud controller, no ALB Controller needed). NLB handles all external traffic.

**Image from ECR:** Traefik image pulled from `ECR/docker-hub/library/traefik` via pull-through cache.

---

### 7. s3-lister App

**What:** Demo app that lists S3 buckets using Pod Identity — no hardcoded AWS credentials anywhere.

**Architecture:**
```
Pod spec:
  initContainers:
  - name: s3-fetch (amazon/aws-cli image)
    command: aws s3 ls → writes HTML to /html/index.html
    volume: emptyDir (shared with nginx)
  
  containers:
  - name: nginx
    serves /html/index.html
    volume: emptyDir (same shared volume)
```

**Why init container pattern:**
> "The init container runs once, fetches data, writes to a shared emptyDir volume, then exits. The main nginx container serves that static HTML. It's a clean separation — init does the AWS work, nginx does the serving. We don't need AWS CLI in the nginx container at all."

**Pod Identity flow:**
```
s3-fetch init container starts
→ Pod Identity Agent (DaemonSet on node) intercepts AWS credential request
→ calls EKS Pod Identity service → returns temporary credentials
→ aws s3 ls runs with temporary credentials
→ HTML written → init exits → nginx starts → serves HTML
```

**Helm chart structure:**
```
chart/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml    → init container + nginx + emptyDir
│   ├── service.yaml       → ClusterIP service
│   ├── serviceaccount.yaml → SA that Pod Identity maps to IAM role
│   └── httproute.yaml     → Gateway API HTTPRoute + Gateway (if create=true)
```

---

### 8. CI/CD Pipeline — 4 Workflows

**infra-apply.yaml** (runs on push to `iac/**` or manual):
- Auth: static IAM creds (OIDC chicken-egg — the OIDC provider is created by this workflow)
- Creates S3 state bucket + Docker Hub secret (idempotent) before tofu init
- `tofu apply -parallelism=20`
- Prints outputs (ECR registry, cluster name, role ARN) for GitHub Variables

**bootstrap.yaml** (manual only, after infra-apply):
- Auth: OIDC (role exists now)
- Pre-pushes cert-manager images quay.io → ECR
- Installs Gateway API CRDs, Traefik, cert-manager in order

**ci.yaml** (push/PR to `app/s3-lister/**`):
- Job 1 (lint): `helm lint` + `helm template` — no AWS needed
- Job 2 (deploy): `helm upgrade --install s3-lister` — needs OIDC for AWS ECR + EKS
- Deploy only on push to main (not PRs)

**destroy.yaml** (manual only, requires typing "destroy"):
- Auth: static IAM creds
- Helm uninstall in reverse order (s3-lister → cert-manager → Traefik)
- Wait 60s for NLB ENIs to release
- Get VPC ID from tofu state (reliable even after partial destroy)
- Delete VPC Interface Endpoints (if any remain from old state)
- `tofu destroy -parallelism=20`
- Optional: delete S3 state bucket

**Why static creds for infra-apply + destroy, OIDC for bootstrap + ci?**
> "infra-apply creates the OIDC provider — chicken-and-egg. destroy needs S3 state bucket access which the OIDC role doesn't have. bootstrap and ci run after infra-apply, so the OIDC role exists and they can use it — no long-lived credentials needed."

---

### 9. The DependencyViolation Bug — Good STAR Story

**Situation:**
Destroy workflow kept failing for 6+ runs across multiple sessions. Subnet deletion was throwing `DependencyViolation`. The error was there from the beginning but the fix kept missing the root cause.

**Task:**
Fix the destroy workflow permanently so any future destroy succeeds on first run.

**Action:**
Manual inspection of all ENIs in the VPC revealed their description was `VPC Endpoint Interface` — not EKS hyperplane ENIs as previously assumed. The real root cause: 6 VPC Interface Endpoints (eks, ecr.api, ecr.dkr, ec2, sts, eks-auth) each created 2 ENIs in private subnets = 12 ENIs total. When OpenTofu tried to delete subnets, these ENIs were still attached.

Two fixes applied:
1. **destroy.yaml:** explicitly delete VPC endpoints before `tofu destroy`, wait for ENIs to clear (polling loop, up to 120 seconds)
2. **VPC module:** removed all 6 interface endpoints from IaC entirely — nodes in public subnets don't need them (saves $87/month, removes 7 minutes from apply time)

**Result:**
Zero manual cleanup steps. Destroy workflow succeeds on first run. $87/month saved. Apply 7 minutes faster.

---

## 15 Interview Questions — Pre-Loaded Answers

**Q1: Walk me through your project architecture.**
Use the 30-second pitch + architecture diagram description. Then offer to go deeper on any component.

**Q2: Why EKS over ECS or Fargate?**
> "ECS is simpler but proprietary. Fargate has no node visibility. EKS gives full K8s API — portable skills, portable workloads. If we ever need to move to GKE or AKS, our Helm charts and manifests work as-is. Also CKA certification is based on K8s, not ECS."

**Q3: Why public subnets for nodes? Isn't that insecure?**
> "Nodes have security groups that only allow traffic from the EKS control plane and specific ports. Public IP doesn't mean the node is exposed — the security group is the firewall. The benefit: nodes reach ECR, STS, EKS-auth via internet through IGW — no NAT Gateway needed, saves $45/month, removes a single point of failure."

**Q4: Explain Pod Identity vs IRSA.**
> "IRSA uses OIDC federation — complex trust policy with exact namespace/SA match, annotation on ServiceAccount, tokens exchanged via OIDC. Pod Identity is simpler — create an association resource that maps SA to IAM role, Pod Identity Agent handles credential injection. No OIDC trust policy to debug, no annotation needed. We use Pod Identity for app-level access and OIDC for GitHub Actions since OIDC is the standard for CI/CD systems."

**Q5: Why Gateway API instead of Ingress?**
> "NGINX Ingress maintenance ended March 2026 — it's being retired. Gateway API is the official replacement. It has role separation: GatewayClass for infra team, Gateway for platform team, HTTPRoute for dev team. Better multi-tenancy, more expressive routing. We're already on the modern standard."

**Q6: What does cert-manager do in your setup?**
> "cert-manager automates TLS certificate lifecycle. We pre-push its images from quay.io to ECR in bootstrap because quay.io doesn't support ECR pull-through cache. cert-manager is installed and ready — activating TLS requires a ClusterIssuer pointing to Let's Encrypt and a Certificate CR per domain. cert-manager handles the ACME challenge through Traefik's Gateway API integration, stores cert as K8s Secret, and auto-renews 30 days before expiry."

**Q7: Why OpenTofu instead of Terraform?**
> "HashiCorp changed Terraform's license to BSL in 2023 — it's no longer open source. OpenTofu is the Linux Foundation fork, 100% open source, API-compatible with Terraform. For any production or learning environment I prefer genuinely open source tooling."

**Q8: How does your CI/CD handle authentication to AWS?**
> "Two methods: static IAM credentials for infra-apply and destroy — because infra-apply creates the OIDC provider (chicken-and-egg problem) and destroy needs S3 state bucket access. OIDC for bootstrap and ci workflows — no long-lived credentials, GitHub Actions assumes the IAM role via OIDC federation, temporary credentials per run."

**Q9: What is ECR pull-through cache and why did you use it?**
> "Docker Hub rate-limits pulls — 100 per 6 hours for anonymous. In a cluster with multiple nodes, you can exhaust this quickly. ECR pull-through cache mirrors Docker Hub in your private ECR — first pull goes to Docker Hub, subsequent pulls served from ECR cache. No rate limits, private registry, no credentials needed on nodes for Docker Hub images."

**Q10: Walk me through the s3-lister app architecture.**
> "It's an init container pattern demonstrating Pod Identity. The init container runs amazon/aws-cli, calls aws s3 ls to list S3 buckets, writes an HTML file to a shared emptyDir volume, then exits. The main nginx container serves that HTML. Pod Identity Agent on the node injects temporary AWS credentials automatically — no hardcoded keys, no annotations on the pod, just a ServiceAccount mapped to an IAM role via Pod Identity Association."

**Q11: What went wrong with your destroy workflow and how did you fix it?**
Use the DependencyViolation STAR story — 6 failed runs, misdiagnosed as EKS hyperplane ENIs, real cause was VPC Interface Endpoint ENIs, fixed by explicit endpoint deletion + removed endpoints from IaC.

**Q12: How would you add monitoring to this setup?**
> "Deploy kube-prometheus-stack via Helm — one chart gives Prometheus Operator, Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics. Add ServiceMonitor CRs for app-level scraping. Add Grafana Alloy as DaemonSet for log collection to Loki. Use RED method dashboards for s3-lister, USE method for nodes. Set up SLO burn rate alerts in Alertmanager for Slack."

**Q13: How would you handle secrets in this setup?**
> "Currently the only secret is Docker Hub credentials in AWS Secrets Manager, managed by infra-apply workflow. For app-level secrets I'd deploy External Secrets Operator — it syncs secrets from AWS Secrets Manager into K8s Secrets automatically with a configurable refresh interval. Secrets never in Git, never hardcoded."

**Q14: What cost optimizations did you make?**
> "Three main ones: removed 6 VPC Interface Endpoints saving $87/month, nodes in public subnets removing NAT Gateway saving $45/month, and node_min=0 allowing the node group to scale to zero when idle. Total infra cost reduction: ~$132/month plus variable savings from scale-to-zero."

**Q15: What would you add if you had more time?**
> "Karpenter for node autoscaling — provisioning nodes in under 60 seconds vs manual sizing. KEDA for s3-lister to scale to zero when no traffic. External Secrets Operator for app-level secret management. Monitoring stack — kube-prometheus-stack with RED method dashboards and SLO alerts. ArgoCD for GitOps — replacing the helm upgrade in ci.yaml with a pull-based model. And split IaC into base layer (VPC, EKS) and apps layer (ECR, IAM, S3) so app changes don't require re-running the 17-minute cluster apply."

---

## Numbers to Have Ready

| Metric | Value |
|--------|-------|
| Apply time | ~17 min (was ~24 min before -parallelism=20) |
| Destroy time | ~10-12 min |
| EKS version | 1.33 |
| Node type | t3.medium (2 vCPU, 4GB) |
| Node count | 2 (min 0, max configurable) |
| Add-ons | 6 (vpc-cni, kube-proxy, coredns, ebs-csi, pod-identity-agent, metrics-server) |
| Workflows | 4 (infra-apply, bootstrap, ci, destroy) |
| VPC endpoints removed | 6 (saved $87/month) |
| NAT Gateway removed | 1 (saved $45/month) |
| Total monthly savings | ~$132 |
| cert-manager version | 1.17.0 (current: 1.20.2) |
| Gateway API version | v1.5.1 |
| Traefik version | v3.7.1 |
| Parallelism | 20 (was default 10) |

---

## Challenges Faced — STAR Stories

### 1. DependencyViolation — 6 Failed Destroy Runs

**S:** Destroy workflow failed 6+ times with `DependencyViolation` on subnet deletion. Each run the fix attempted was wrong — tried cleaning EKS hyperplane ENIs, adding retry loops, force-deleting SGs.

**T:** Find the real root cause and fix permanently.

**A:** Manually inspected ENI descriptions in the VPC. All blocking ENIs showed description `VPC Endpoint Interface` — not EKS hyperplane. The 6 VPC Interface Endpoints each created 2 ENIs in private subnets = 12 ENIs. OpenTofu's async ENI teardown (2+ minutes) overlapped with subnet deletion. Fixed destroy.yaml to explicitly delete endpoints and poll until ENIs clear. Also removed all interface endpoints from IaC — public subnet nodes don't need them.

**R:** Destroy succeeds first run. $87/month saved. Apply 7 minutes faster.

### 2. cert-manager ImagePullBackOff

**S:** After bootstrap workflow, cert-manager pods were in ImagePullBackOff. Nodes couldn't reach quay.io.

**T:** Get cert-manager images available to nodes without requiring internet access to quay.io.

**A:** quay.io doesn't support ECR pull-through cache (only Docker Hub does). Added image pre-push step to bootstrap.yaml — runner has internet, pulls 4 images from quay.io, pushes to ECR under `quay-io/jetstack/` prefix. Helm install overrides all 4 image repositories to ECR.

**R:** cert-manager installs cleanly. Pattern documented — any registry not supporting pull-through cache uses manual pre-push approach.

### 3. RTK Filtering Pipeline Output

**S:** S3 state bucket teardown script using `grep | xargs | paste` pipeline was silently producing no output. RTK (token-killing proxy) was filtering the intermediate command output, breaking dynamic pipelines.

**T:** Delete all 24 object versions from the S3 bucket to allow bucket deletion.

**A:** Abandoned dynamic pipeline approach. Built hardcoded JSON payload with all 24 version IDs directly and passed to `aws s3api delete-objects --delete "$PAYLOAD"` as a single command. RTK can't filter a hardcoded payload.

**R:** All versions deleted, bucket removed, teardown script completed.

---

## "What Would You Improve?" — Best Answers

1. **Karpenter** — replace manual t3.medium node sizing with Karpenter NodePool. Nodes provision in < 60s, spot-aware, consolidation saves money automatically.

2. **IaC split into layers** — base layer (VPC, EKS — changes rarely, ~17 min apply) and apps layer (ECR, IAM, S3 — changes often, ~3 min apply). Today any change to IAM roles triggers the full 17-minute apply.

3. **ArgoCD** — replace `helm upgrade` in ci.yaml with GitOps. Git is source of truth, drift detection, no CI tool needs cluster credentials.

4. **KEDA** — scale s3-lister to zero when no traffic. Currently minimum 1 pod even when idle.

5. **External Secrets Operator** — sync Docker Hub secret and any future app secrets from AWS SM automatically. Currently the Docker Hub secret is managed manually in infra-apply.

6. **Monitoring** — kube-prometheus-stack + Grafana Alloy + Loki. RED method dashboards for s3-lister, SLO alerts to Slack.

7. **Spot instances** — node group on spot saves ~83% on node costs. Add PDB to protect against spot interruptions.
