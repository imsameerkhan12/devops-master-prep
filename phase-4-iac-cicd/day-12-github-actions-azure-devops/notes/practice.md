# Day 12 Practice Notes — GitHub Actions + CI/CD Production Setup

---

## 1. CI/CD Production Patterns — Companies Actually Use

### Hindi

```
4 main patterns hain industry mein:

1. Separate Repos (Mid-Large companies — Spotify, Airbnb, fintech):
   infra-repo  → Platform/DevOps team owns → strict access
   app-repo    → Dev team owns → faster iteration
   Kyu: Infra change = high blast radius, App change = low blast radius
        Different approval requirements, different on-call

2. Monorepo (Big Tech — Google, Meta, Uber):
   Sab ek repo mein → path-based triggers
   Atomic commits — infra + app ek saath
   Challenge: complex pipelines, slow CI, need Bazel/Nx/Turborepo

3. GitOps with ArgoCD/Flux (2023+ K8s standard):
   gitops-config-repo = desired state (Helm values, manifests)
   ArgoCD cluster ke andar watches repo
   Change detect → auto-sync → deploy
   Drift hone pe → auto-heal

4. Trunk Based + Feature Flags (Startups → scale-ups):
   Ek hi branch: main
   Har commit → deploy (continuous deployment)
   Feature flags se incomplete features hide karo
   Netflix, Amazon internal teams
```

### English — Interview Answer

> "We follow GitOps with ArgoCD — separate repos for infrastructure (OpenTofu) and application config. The app CI pipeline builds the image, pushes to ECR, then updates the image tag in our GitOps config repo. ArgoCD detects the change and syncs to the cluster. Infrastructure changes go through a separate pipeline with manual approval on the plan before apply. This gives us full audit trail in git and eliminates direct cluster access from pipelines."

---

## 2. Push vs Pull Model — Critical Concept

### Hindi

```
Push Model (GitHub Actions → cluster directly):
  Pipeline → kubectl apply / helm upgrade
  Pipeline ko cluster credentials chahiye (kubeconfig)
  Pipeline compromise = cluster compromise
  Drift hone pe pata nahi chalta

Pull Model — GitOps (ArgoCD/Flux):
  ArgoCD cluster ke andar install hai
  Repo watch karta hai (poll ya webhook)
  Change detect → cluster mein apply karta hai
  Cluster credentials bahar nahi jaati
  Drift auto-detect + auto-heal
  Full audit trail = git history
```

**Diagram:**
```
Push:
  Developer → GitHub → Pipeline → AWS credentials → kubectl/helm → Cluster

Pull (GitOps):
  Developer → GitHub (repo change)
                    ↑
              ArgoCD (inside cluster) watches → auto-sync
  No pipeline → cluster connection needed
```

### English — Interview Answer

> "Pull model is more secure — ArgoCD runs inside the cluster and pulls desired state from git. Nothing outside the cluster needs credentials to deploy. Push model requires giving pipelines cluster access, which increases attack surface. With ArgoCD, we also get automatic drift detection and self-healing — if someone manually changes something in the cluster, ArgoCD reverts it to match git."

---

## 3. Self-Hosted Runners on EKS — Actions Runner Controller (ARC)

### Hindi

```
GitHub-hosted runners kya problem dete hain:
  ❌ VPC ke bahar hain → private resources access nahi
  ❌ Tools download karne padte hain (tofu, helm, kubectl)
  ❌ Private repos ke liye cost: $0.008/min
  ❌ GitHub OIDC → AWS = extra complexity

Self-hosted runners on EKS kya dete hain:
  ✅ Same VPC → private EKS endpoint directly accessible
  ✅ Custom image → tofu, helm, kubectl pre-installed
  ✅ Pod Identity → AWS creds automatically (no secrets needed)
  ✅ Already running nodes pe chalta hai → extra cost nahi
  ✅ Auto-scaling — idle pe zero pods, job aaya → pod spin up
```

**Tool: Actions Runner Controller (ARC):**
```
GitHub ka official Kubernetes operator
  github.com/actions/actions-runner-controller

2 components:
  1. ARC Controller  → operator — runner pods manage karta hai
  2. Runner Scale Set → actual runners — job queue se scale hota hai

Runner pods = ephemeral:
  Job aaya → pod spin up → job run → pod terminate
  Clean state har baar — no leftover artifacts
```

### Flow — job kaise run hoti hai:

```
1. Dev PR push karta hai → GitHub job queue mein jaata hai
2. GitHub → ARC webhook → "job available"
3. ARC Controller → Runner pod spin up (arc-runners namespace)
4. Pod Identity Agent → AWS creds inject (same as s3-lister pattern)
5. Runner registers with GitHub → job pick up karta hai
6. tofu plan / helm upgrade / docker build run hota hai
7. Job complete → runner pod terminate
8. Plan output → GitHub PR comment mein post
```

### Credential flow comparison:

```
GitHub-hosted + OIDC:
  GitHub DC → OIDC provider → AWS STS → temp creds
  Extra: GitHub OIDC IAM provider banao, IAM role banao
  Runner VPC ke bahar → private endpoint → extra config

Self-hosted on EKS + Pod Identity:
  Runner Pod → Pod Identity Agent → AWS STS → temp creds
  Same pattern: s3-lister, ebs-csi — already jaante hain
  Runner VPC ke andar → private endpoint direct access
  No GitHub OIDC provider needed
  Cleaner ✅
```

### English — Interview Answer

> "We use ARC (Actions Runner Controller) to run GitHub Actions self-hosted runners on our EKS cluster. Runners use Pod Identity for AWS credentials — same pattern as our application pods, no stored secrets anywhere. Since runners are inside the VPC, they reach the private EKS endpoint directly without any special networking. ARC auto-scales runner pods from zero based on the job queue — idle costs nothing. Each runner pod is ephemeral — spins up for one job, terminates after. This gives us clean state every run and no resource leakage."

---

## 4. What We'll Build — Full Architecture

### Repo Structure

```
DEVOPS-REMASTER/
├── iac/
│   └── envs/dev/
│       └── main.tf        ← runner IAM role + Pod Identity add karenge
├── app/
│   ├── arc/
│   │   └── values.yaml    ← ARC runner scale set config
│   ├── argocd/
│   │   └── application.yaml  ← ArgoCD Application CRD
│   └── s3-lister/chart/   ← ArgoCD ye watch karega
└── .github/
    └── workflows/
        ├── iac-plan.yml   ← runs-on: arc-runner-set (self-hosted)
        └── iac-apply.yml  ← runs-on: arc-runner-set (self-hosted)
```

### Install Order (after tofu apply):

```bash
# 1. ArgoCD install
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  -f app/argocd/values.yaml

# 2. ARC Controller install
helm upgrade --install arc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  -n arc-systems --create-namespace

# 3. Runner Scale Set install
helm upgrade --install arc-runner-set \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  -n arc-runners --create-namespace \
  -f app/arc/values.yaml

# 4. ArgoCD Application apply
kubectl apply -f app/argocd/application.yaml
```

### IaC additions — IAM Role for runners (main.tf mein):

```hcl
# Runner pods ko AWS access chahiye (tofu state, ECR, EKS)
resource "aws_iam_role" "github_runner" {
  name = "${var.cluster_name}-github-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# Pod Identity — arc-runners namespace ke pods ko ye role milegi
resource "aws_eks_pod_identity_association" "github_runner" {
  cluster_name    = module.eks.cluster_name
  namespace       = "arc-runners"
  service_account = "arc-runner-set"
  role_arn        = aws_iam_role.github_runner.arn
}
```

### GitHub Actions workflow (self-hosted):

```yaml
# .github/workflows/iac-plan.yml
name: OpenTofu Plan

on:
  pull_request:
    paths: ['iac/**']

permissions:
  pull-requests: write   # PR comment ke liye
  contents: read

jobs:
  plan:
    runs-on: arc-runner-set   # self-hosted EKS runner
    steps:
      - uses: actions/checkout@v4

      # No aws-actions/configure-aws-credentials needed!
      # Pod Identity automatically creds inject kar chuka hai

      - name: tofu init
        run: tofu init
        working-directory: iac/envs/dev

      - name: tofu plan
        run: tofu plan -var-file=dev.tfvars -out=plan.tfplan -no-color
        working-directory: iac/envs/dev

      - name: Post plan to PR
        uses: actions/github-script@v7
        with:
          script: |
            const plan = require('fs').readFileSync('iac/envs/dev/plan.tfplan.txt', 'utf8')
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## OpenTofu Plan\n```\n' + plan + '\n```'
            })
```

---

## 5. ArgoCD — GitOps Controller

### Hindi

```
ArgoCD kya hai:
  Kubernetes controller — cluster ke andar chalta hai
  Git repo watch karta hai (poll every 3 min ya webhook)
  Desired state (git) vs Actual state (cluster) compare karta hai
  Difference hai → sync karta hai

Application CRD:
  "Is repo ka ye path watch karo
   Is cluster ke is namespace mein apply karo
   Auto-sync: on"
```

### ArgoCD Application for s3-lister:

```yaml
# app/argocd/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: s3-lister
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/imsameerkhan12/devops-master-prep
    targetRevision: main
    path: app/s3-lister/chart          # Helm chart yahan hai
    helm:
      valueFiles:
        - values.yaml

  destination:
    server: https://kubernetes.default.svc   # same cluster
    namespace: default

  syncPolicy:
    automated:
      prune: true      # git se delete hoa → cluster se bhi delete
      selfHeal: true   # manual change → git se revert
    syncOptions:
      - CreateNamespace=true
```

### English — Interview Answer

> "ArgoCD continuously reconciles cluster state with git. The Application CRD defines what to watch (repo path, branch) and where to deploy (cluster, namespace). With `automated.selfHeal: true`, any manual kubectl change gets reverted to match git within minutes — git is the single source of truth. `prune: true` ensures resources deleted from git are also deleted from the cluster."

---

---

## 6. What We Actually Built — Day 12 Hands-On

### Architecture we coded:

```
Git push to main
      ↓
GitHub Actions (bootstrap.yaml)
  runs-on: ubuntu-latest (GitHub-hosted)
  AWS auth: OIDC → assume IAM role (no static creds)
      ↓
Installs on EKS:
  1. Gateway API CRDs v1.5.1
  2. Traefik (NLB + Gateway API)
  3. ARC Controller (arc-systems namespace)
  4. ARC GitHub App Secret (arc-runners namespace)
  5. ARC RunnerSet (arc-runner-set label)
  6. ArgoCD (argocd namespace)
  7. cert-manager (cert-manager namespace)
  8. ArgoCD Application → s3-lister auto-deploys

After bootstrap, future CI (ci.yaml):
  runs-on: arc-runner-set (EKS self-hosted runner)
  helm lint + helm template + argocd refresh
```

---

## 7. GitHub Actions OIDC — How It Works

### Hindi

```
Problem: GitHub Actions ko AWS access chahiye
Wrong way: AWS_ACCESS_KEY_ID secret store karo → rotate karna padta hai, leak risk
Right way: OIDC (OpenID Connect)

Flow:
1. GitHub workflow run hota hai
2. GitHub JWT token generate karta hai → workflow ke baare mein claims:
   "repo: imsameerkhan12/devops-master-prep"
   "ref: refs/heads/main"
   "job: bootstrap"
3. Workflow → AWS STS ko bolta hai: "ye token hai, mujhe role do"
4. AWS → GitHub OIDC provider pe verify karta hai → trust karta hai
5. AWS → short-lived credentials deta hai (15 min valid)
6. Workflow → credentials use karta hai → kaam karta hai

GitHub OIDC provider URL: https://token.actions.githubusercontent.com
```

### IaC mein kya bana:

```hcl
# 1. AWS ko batao: GitHub ke tokens trust karo
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

# 2. IAM Role — sirf imsameerkhan12 repos assume kar sakte hain
resource "aws_iam_role" "github_actions" {
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:imsameerkhan12/*:*"
        }
      }
    }]
  })
}

# 3. EKS Access Entry — role ko cluster admin banao (modern, no aws-auth)
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
}
```

### Workflow mein usage:

```yaml
permissions:
  id-token: write   # OIDC token generate karne ki permission

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ vars.AWS_ROLE_ARN }}   # GitHub Variable (not secret)
      aws-region: us-east-1
  # Ab se sab AWS commands → OIDC credentials se run honge
```

### English — Interview Answer

> "We use GitHub OIDC to authenticate with AWS — no stored credentials anywhere. GitHub generates a JWT token per workflow run, AWS verifies it against our registered OIDC provider, and issues a short-lived IAM role session. The IAM role trust policy scopes it to our org only — `repo:imsameerkhan12/*:*`. Credentials expire after 15 minutes automatically."

---

## 8. ARC — GitHub App Auth (Not PAT)

### Hindi

```
PAT (Personal Access Token) — wrong way:
  Tied to user account → user leaves company → runners break
  Wide permissions → security risk
  Manual rotation needed

GitHub App — right way:
  Org/account level entity — not tied to any user
  Fine-grained permissions (Actions: Read+Write, Metadata: Read)
  Private key auto-rotates (app manages it)
  Installation ID = scope (which repos can use it)
```

### What we set up:

```
GitHub App: devops-lab-arc
  App ID:           3710409
  Installation ID:  132252489
  Permissions:
    Actions:   Read & Write
    Metadata:  Read-only (mandatory)

K8s Secret (created by bootstrap workflow — never in git):
  name: arc-github-app-secret
  namespace: arc-runners
  keys:
    github_app_id              → 3710409
    github_app_installation_id → 132252489
    github_app_private_key     → <PEM content from GitHub secret>
```

### Workflow secret management:

```
PEM file content → GitHub Repo Secret: ARC_GITHUB_APP_PRIVATE_KEY
                        ↓
Bootstrap workflow reads it → creates K8s secret via kubectl
                        ↓
ARC RunnerSet references K8s secret → authenticates with GitHub
```

---

## 9. Bootstrap vs Destroy Workflow Design

### Bootstrap (bootstrap.yaml)

```
Trigger: workflow_dispatch (manual) OR push to main (auto on path changes)
Runner: ubuntu-latest (GitHub-hosted) — ARC doesn't exist yet
Auth: OIDC
Concurrency group: platform-ops (no parallel runs)
Helm flag: --atomic (rolls back on failure, not just --wait)

Install order:
  1. Gateway API CRDs        (cluster-scoped, must be first)
  2. Traefik                 (needs Gateway API CRDs)
  3. ARC Controller          (arc-systems)
  4. ARC Secret              (idempotent: dry-run | apply)
  5. ARC RunnerSet           (arc-runners, references secret)
  6. ArgoCD                  (argocd)
  7. cert-manager            (cert-manager, CRDs included)
  8. ArgoCD Application      (s3-lister — ArgoCD then handles deploy)
```

### Destroy (destroy.yaml)

```
Trigger: workflow_dispatch ONLY (manual — never auto-triggered)
Guard: inputs.confirm must equal 'destroy' (hard gate at job level)
Runner: ubuntu-latest (ARC is being destroyed — can't use it)

Input options:
  confirm: "destroy"                      (required, typed confirmation)
  destroy_state_bucket: true/false        (optional, default false)

Uninstall order (reverse of bootstrap):
  1. ArgoCD Application  → stop auto-sync (prevents redeploy during destroy)
  2. s3-lister           → app resources
  3. ArgoCD              → GitOps controller
  4. cert-manager        → CRDs + controller
  5. ARC RunnerSet       → runner pods
  6. ARC Controller      → operator
  7. Traefik             → NLB DELETED HERE (cloud controller removes it)
  8. Wait 60s            → NLB ENIs release from subnets
  9. Force-delete NLBs   → in case cloud controller didn't clean up
  10. tofu destroy        → EKS, VPC, ECR, IAM, S3, all infra
  11. teardown-state-backend.sh --yes  → (optional) state bucket + secret
```

### Why this order matters — NLB gotcha:

```
Traefik creates LoadBalancer Service → K8s cloud controller → AWS creates NLB
NLB has ENIs attached to our private subnets
If tofu destroys EKS first → cloud controller dies → NLB stuck
NLB ENIs still in subnets → tofu destroy VPC fails: DependencyViolation

Fix: always helm uninstall traefik BEFORE tofu destroy
     K8s sees Service deleted → cloud controller removes NLB → subnets free
```

---

## 10. ECR Pull-Through Cache — All Registries

### What we added for Day 12:

```
Registry       ECR Prefix    Used by
─────────────────────────────────────────────────────────────
docker.io      docker-hub    nginx, aws-cli, redis (argocd)
ghcr.io        ghcr-io       ARC runner, ARC controller
quay.io        quay-io       ArgoCD, cert-manager
```

### IAM policy for nodes (updated):

```hcl
# Node group needs BatchImportUpstreamImage for all prefixes
Resource = [
  "arn:aws:ecr:region:account:repository/docker-hub/*",
  "arn:aws:ecr:region:account:repository/ghcr-io/*",
  "arn:aws:ecr:region:account:repository/quay-io/*",
]
```

### Pre-created ECR repos (prevent orphans on destroy):

```
ghcr-io/actions/actions-runner
ghcr-io/actions/gha-runner-scale-set-controller
quay-io/argoproj/argocd
quay-io/jetstack/cert-manager-controller
quay-io/jetstack/cert-manager-cainjector
quay-io/jetstack/cert-manager-webhook
quay-io/jetstack/cert-manager-startupapicheck
docker-hub/library/redis
```

---

## 11. GitHub Repo Setup — After tofu apply

**Required before running bootstrap workflow:**

```
Settings → Secrets and Variables → Actions

Secrets (sensitive):
  ARC_GITHUB_APP_PRIVATE_KEY  → cat ~/Downloads/devops-lab-arc.*.pem

Variables (non-sensitive):
  AWS_ROLE_ARN  → tofu output github_actions_role_arn
  ECR_REGISTRY  → tofu output ecr_registry
  CLUSTER_NAME  → devops-lab-eks
```

---

---

## 12. ECR Pull-Through Cache — ghcr.io + quay.io Gotcha

### Hindi

```
Assumption tha: ghcr.io aur quay.io public registries hain → no auth needed
Reality: AWS ECR pull-through cache ke liye DONO registries ko credentials chahiye
         chahe image public ho tab bhi

Error mila:
  UnsupportedUpstreamRegistryException:
  The specified upstream registry requires authentication.
  Specify a valid Secrets Manager ARN containing the upstream registry credentials.

Registries + auth requirement:
  docker.io  → optional (rate limiting without auth, we already have creds)
  ghcr.io    → REQUIRED (GitHub PAT with read:packages scope)
  quay.io    → REQUIRED (Quay.io account credentials)
  public.ecr.aws → no auth (ECR Public)
```

### Solution — Pre-push from GitHub-hosted runner

```
Problem:
  EKS nodes (private subnet, no NAT) → can't reach ghcr.io/quay.io directly
  ECR pull-through cache → needs credentials we don't want to set up

Solution:
  GitHub-hosted runner (ubuntu-latest) → HAS internet access
  Runner pulls from public registry → pushes to ECR → nodes pull from ECR

Flow:
  bootstrap workflow (ubuntu-latest, internet):
    docker pull ghcr.io/actions/actions-runner:latest
    docker tag  ghcr.io/...  ECR_REGISTRY/ghcr-io/actions/actions-runner:latest
    docker push ECR_REGISTRY/ghcr-io/actions/actions-runner:latest
          ↓
    (nodes pull from ECR via VPC endpoint — no internet needed)
```

### Why this is better than pull-through cache for these registries:

```
Pull-through cache:
  ✅ Auto-imports on first pull (no pre-seeding)
  ❌ Needs Secrets Manager credentials for ghcr.io + quay.io
  ❌ Two new accounts (GitHub PAT + Quay.io)
  ❌ More IaC complexity (credential_arn in resource)

Pre-push from runner:
  ✅ Zero new accounts/credentials
  ✅ Explicit control over what's in ECR (no surprise imports)
  ✅ Simpler IaC (plain ECR repos, no pull-through cache rules)
  ✅ Works because bootstrap runner has internet
  ❌ Bootstrap takes longer (pull + push each image)
  ❌ Must update versions manually when upgrading
```

### IaC changes made:

```hcl
# REMOVED — both require credentials in AWS ECR pull-through
# resource "aws_ecr_pull_through_cache_rule" "ghcr" { ... }
# resource "aws_ecr_pull_through_cache_rule" "quay" { ... }

# KEPT as plain ECR repos — bootstrap workflow pushes images here
resource "aws_ecr_repository" "ghcr_actions_runner" {
  name         = "ghcr-io/actions/actions-runner"
  force_delete = true
  # No depends_on = pull-through rule (rule doesn't exist anymore)
}

# IAM policy — only docker-hub/* needs BatchImportUpstreamImage
# (ghcr-io/*, quay-io/* removed — those are now plain repos)
Resource = "arn:aws:ecr:region:account:repository/docker-hub/*"
```

### Bootstrap workflow — pre-push step:

```bash
# ECR login — runner authenticates with AWS via OIDC
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin "$ECR"

push_image() {
  docker pull "$1" && docker tag "$1" "$2" && docker push "$2"
}

# ARC — controller tag matches chart version
push_image "ghcr.io/actions/actions-runner:latest" \
           "${ECR}/ghcr-io/actions/actions-runner:latest"

# ArgoCD — get tag from chart appVersion (don't hardcode)
ARGOCD_TAG="v$(helm show chart argo/argo-cd --version 7.8.0 \
  | grep ^appVersion | awk '{print $2}' | tr -d '"')"
push_image "quay.io/argoproj/argocd:${ARGOCD_TAG}" \
           "${ECR}/quay-io/argoproj/argocd:${ARGOCD_TAG}"

# cert-manager — image version == chart version
CM_TAG="v1.17.0"
for img in cert-manager-controller cert-manager-cainjector \
           cert-manager-webhook cert-manager-startupapicheck; do
  push_image "quay.io/jetstack/${img}:${CM_TAG}" \
             "${ECR}/quay-io/jetstack/${img}:${CM_TAG}"
done
```

### Key trick — dynamic ArgoCD tag:

```bash
# Never hardcode image tags — get from chart metadata
ARGOCD_TAG="v$(helm show chart argo/argo-cd --version 7.8.0 \
  | grep ^appVersion | awk '{print $2}' | tr -d '"')"

# Then wire into helm install:
--set "global.image.tag=${ARGOCD_TAG}"
# This ensures pushed image tag == what chart expects
```

### English — Interview Answer

> "We hit an AWS limitation — ECR pull-through cache requires credentials for ghcr.io and quay.io even for public images. Instead of creating extra accounts and secrets, we use the bootstrap workflow's GitHub-hosted runner which has internet access. It pulls images from ghcr.io and quay.io, then pushes them to ECR. EKS nodes in private subnets pull from ECR via VPC endpoint — they never need internet. The image tag is dynamically fetched from the Helm chart's appVersion so we never hardcode or mismatch versions."

---

## 13. infra-apply Workflow — Variable Precedence Bug + Fix

### Hindi

```
Bug: TF_VAR_aws_profile="" env var set kiya tha
     Expect tha: dev.tfvars ka aws_profile="sameer" override ho jaayega
     Reality: -var-file BEATS TF_VAR_* env vars

OpenTofu variable precedence (low → high):
  1. default values in variable block    (lowest)
  2. TF_VAR_* environment variables
  3. terraform.tfvars / *.auto.tfvars
  4. -var-file flags
  5. -var flags                          (highest)

Fix: -var flag use karo (highest priority)
  tofu apply --var-file=dev.tfvars --var='aws_profile='
  
  -var-file=dev.tfvars sets  aws_profile="sameer"
  --var='aws_profile='  overrides to empty string
  Provider: profile = var.aws_profile != "" ? var.aws_profile : null
            → null → use default credential chain (OIDC in GitHub Actions)
```

### English — Interview Answer

> "In OpenTofu, `-var-file` has higher precedence than `TF_VAR_*` environment variables. So setting `TF_VAR_aws_profile=''` doesn't override what's in dev.tfvars. The fix is to add `--var='aws_profile='` explicitly — `-var` flags are the highest precedence and beat `-var-file`. Combined with the provider conditional `profile = var.aws_profile != "" ? var.aws_profile : null`, an empty string means 'use the default credential chain' which in GitHub Actions is the OIDC-assumed role."

---

## 14. Bootstrap Errors — Run 3 + 4 Fixes

### Hindi

```
Run #3 fail: bootstrap.yaml
Error: quay.io/argoproj/argocd:vv2.14.1 — manifest unknown

Root Cause: Double 'v' prefix bug
  helm show chart appVersion → "v2.14.1"  (already has v)
  Code: ARGOCD_TAG="v$(... | tr -d '"')"  → "vv2.14.1"  ← WRONG

Fix: Remove extra 'v' prefix
  ARGOCD_TAG="$(... | tr -d '"')"  → "v2.14.1"  ← CORRECT
  
Lesson: Check what helm show chart appVersion actually returns before assuming format.
  argocd chart: appVersion includes 'v' prefix
  cert-manager chart: appVersion does NOT include 'v' (so CM_TAG="v${{ ... }}" is right)

---

Run #4 fail: bootstrap.yaml
Error: StatefulSet/argocd/argocd-application-controller not ready (timeout)
  status: InProgress (pod was starting, just slow)

Root Cause: --atomic --timeout=5m too short for first install on t3.medium (1 node)
  
  Why slow on first install:
  1. ArgoCD image (~500MB) → pulled from ECR via VPC endpoint (first time)
  2. Redis image (7-alpine) → docker-hub pull-through cache
     First pull = ECR sees no image → fetch from docker.io → cache in ECR → node downloads
     This can take 3-4 min on cold start
  3. All this on 1 t3.medium (2 vCPU, 4GB) with Traefik + ARC already running
  
  --atomic rolls back the release on timeout → clean state but shows as failure

Fix: Increase timeout
  --atomic --timeout=10m  ← gives enough headroom for first-pull image caching

Production tip: On real clusters (bigger nodes, multiple nodes, images already cached)
  5m is usually fine. Only a problem on fresh install on small dev nodes.
```

### English — Interview Answer

> "Two gotchas during bootstrap: First, ArgoCD's Helm chart `appVersion` already includes the `v` prefix (e.g., `v2.14.1`), so don't prepend another `v` — that produces `vv2.14.1` which doesn't exist on quay.io. Second, on a fresh cluster with a small node, `--atomic --timeout=5m` is too short for ArgoCD's first install. The argocd image (~500MB) plus redis pulling through the docker-hub ECR pull-through cache for the first time can easily take 6-8 minutes. We bumped to `--timeout=10m`. `--atomic` is still the right flag — it rolls back the release cleanly on failure rather than leaving a partially-installed release."

---

## Concept Summary

| Concept | Key Point |
|---|---|
| Push vs Pull | Pull (ArgoCD) = no cluster creds in pipeline, drift auto-heal |
| Separate repos | Infra = high blast radius, App = low — different ownership |
| GitOps | Git = single source of truth, ArgoCD reconciles continuously |
| ARC | Self-hosted runners on EKS, ephemeral pods, scale to zero |
| GitHub App vs PAT | App = org-level, not user-tied, fine-grained perms — always use App |
| GitHub OIDC | No stored AWS creds — short-lived tokens per workflow run |
| OIDC Condition | `repo:imsameerkhan12/*:*` — scope to your org only (security) |
| ArgoCD Application | Watch repo path → deploy to cluster → auto-sync + self-heal |
| Destroy order | Traefik uninstall BEFORE tofu destroy — prevents NLB blocking VPC delete |
| --atomic | Better than --wait — also rolls back Helm release on failure |
| ECR pull-through | ghcr.io + quay.io require creds → pre-push pattern instead |
| Ephemeral runners | Each job = fresh pod — clean state, no artifact leakage |
| appVersion v prefix | ArgoCD chart already has 'v' in appVersion; cert-manager does NOT |
| First-install timeout | ECR pull-through cold start can take 3-4min extra — use 10m for ArgoCD |
| EKS Access Entry | Modern cluster access (no aws-auth ConfigMap) — IAM role → cluster-admin |
