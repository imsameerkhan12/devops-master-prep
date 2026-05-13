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

## Concept Summary

| Concept | Key Point |
|---|---|
| Push vs Pull | Pull (ArgoCD) = no cluster creds in pipeline, drift auto-heal |
| Separate repos | Infra = high blast radius, App = low — different ownership |
| GitOps | Git = single source of truth, ArgoCD reconciles continuously |
| ARC | Self-hosted runners on EKS — Pod Identity, VPC access, ephemeral |
| Self-hosted vs GitHub-hosted | Self-hosted = VPC access + Pod Identity + cheaper + pre-built tools |
| ArgoCD Application | Watch repo path → deploy to cluster → auto-sync + self-heal |
| Ephemeral runners | Each job = fresh pod — clean state, no artifact leakage |
