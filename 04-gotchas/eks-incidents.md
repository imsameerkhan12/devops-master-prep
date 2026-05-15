# EKS Incidents + Production Gotchas
> Real bugs I debugged personally — your strongest interview answers

---

## Real Incidents (Debugging Log)

### Incident 1: nodeadm Timeout — Node Never Joins

**Symptom:** Node group stuck in CREATING for 40+ minutes

**Debug:**
```powershell
aws ec2 get-console-output --instance-id i-0d0adca32e3e6e342 --latest --output text
```
Output: `nodeadm: context deadline exceeded` after 10 min

**Root cause:** `ec2` VPC endpoint missing → nodeadm can't fetch instance metadata

**Fix:** Create `com.amazonaws.us-east-1.ec2` endpoint → terminate old node → ASG creates new → nodeadm completes in 0.85s ✅

---

### Incident 2: CNI Not Initialized — Node NotReady

**Symptom:** Node registered but STATUS=NotReady

**Chain of failure:**
```
eks-auth VPC endpoint missing
  → Pod Identity Agent can't reach eks-auth.us-east-1.api.aws
  → aws-node gets no credentials
  → VPC CNI never initializes
  → Node stays NotReady
```

**Fix:** Create `com.amazonaws.us-east-1.eks-auth` endpoint ✅

---

### Incident 3: kubectl Access Denied

**Symptom:** `error: You must be logged in to the server`

**Root cause:** Cluster created via Console — IAM user not in cluster auth.

**Fix — EKS Access Entries (NOT aws-auth ConfigMap):**
```powershell
aws eks create-access-entry --cluster-name devops-lab-eks `
  --principal-arn arn:aws:iam::271169999916:user/sameer `
  --type STANDARD

aws eks associate-access-policy --cluster-name devops-lab-eks `
  --principal-arn arn:aws:iam::271169999916:user/sameer `
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy `
  --access-scope type=cluster
```

---

### Incident 4: DependencyViolation — 6 Failed Destroy Runs

**Symptom:** `tofu destroy` fails with `DependencyViolation` on subnet deletion

**Wrong diagnosis (tried 5 times):** Cleaning EKS hyperplane ENIs, adding retry loops, force-deleting SGs

**Real root cause:** 6 VPC Interface Endpoints each created 2 ENIs in private subnets = 12 ENIs blocking subnet deletion

**Fix:**
1. `destroy.yaml`: explicitly delete VPC endpoints before `tofu destroy`, poll until ENIs clear
2. Removed all 6 interface endpoints from IaC (nodes in public subnets don't need them)

**Result:** Destroy succeeds first run. $87/month saved. Apply 7 minutes faster. ✅

---

### Incident 5: cert-manager ImagePullBackOff

**Symptom:** cert-manager pods stuck in ImagePullBackOff after bootstrap

**Root cause:** quay.io doesn't support ECR pull-through cache (only Docker Hub does)

**Fix:** Added image pre-push step to bootstrap.yaml:
1. Runner pulls 4 cert-manager images from quay.io
2. Pushes to ECR under `quay-io/jetstack/` prefix
3. Helm install overrides image repositories to ECR

---

## Production Gotcha Patterns

### G1 — t3.medium Pod Limit: 17 Max

```
Formula: max_ENIs × (IPs_per_ENI - 1) + 2
t3.medium: 3 ENIs × 6 IPs → 3×5+2 = 17 max pods
System pods alone: ~16 → only 1 slot for runner pods

Fix — VPC CNI Prefix Delegation:
  ENABLE_PREFIX_DELEGATION=true → t3.medium → 110 pods max
```

### G2 — ARC JIT Token: One-Time Use

```
JIT token = one-time use only
If first pod fails → retry with same expired token → silent failure
Debug signature: exitCode:0, startedAt == finishedAt, empty logs

Fix: Never manually retry — let ARC create fresh EphemeralRunner
     Delete stale: kubectl delete ephemeralrunner -n arc-runners --all
```

### G3 — Kubelet ECR Cache: 12-Hour Poison

```
Node booted without ECR policy → kubelet cached empty ECR auth
Policy attached later → cache still invalid 12 HOURS
Fix (prod): Terminate node → ASG respawns → fresh cache

Lesson: Attach IAM policies BEFORE node group boots.
```

### G4 — Node IAM Policy Lost on Node Group Recreation

```
Wrong: aws iam attach-role-policy via CLI (not in state, not idempotent)

Correct: Explicit aws_iam_role_policy_attachment OUTSIDE the module
  resource "aws_iam_role_policy_attachment" "node_worker" {
    role       = module.eks.node_group_role_name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  }
  # Independent resource — survives node group recreation
```

### G5 — ARC githubConfigUrl: Repo-Level for Personal Accounts

```
❌ Wrong: githubConfigUrl = "https://github.com/imsameerkhan12"
✅ Fix:   githubConfigUrl = "https://github.com/imsameerkhan12/devops-master-prep"

Why: Personal accounts need repo-level URL, not user-level
```

### G6 — GitHub App: Administration R+W Required

```
Required permissions for ARC GitHub App:
  Actions:        Read & Write    ← job queue access
  Administration: Read & Write    ← runner register/deregister ← CRITICAL
  Metadata:       Read-only
```

### G8 — ArgoCD Too Heavy for t3.medium

```
argocd-application-controller: ~512MB RAM
Redis (required):               ~100MB RAM
Total with Traefik + ARC + cert-manager: >4GB → node OOM

Decision: Dropped ArgoCD. Use push model (ARC → helm upgrade).
Alternative: Flux CD — lighter, CNCF graduated, no UI overhead
```

### G11 — Git Bash Path Mangling

```
Windows Git Bash converts /aws → C:/Program Files/Git/aws
Fix: Use PowerShell for AWS CLI commands
  Or: MSYS_NO_PATHCONV=1 aws ...
```

### G12 — AWS Resource Description: ASCII Only

```
Error: InvalidParameterValue — Character sets beyond ASCII not supported
Cause: Em dash — (U+2014) in description string
Fix: Replace — with regular hyphen -
```

### G14 — Destroy Workflow OIDC Missing S3 State Access

```
infra-apply: static IAM creds → admin → S3 OK
destroy:     OIDC role → tofu init → HeadObject → 403 Forbidden

Fix: Ensure destroy workflow has s3:GetObject, PutObject, DeleteObject on state bucket
Lesson: If apply/destroy use different auth → test BOTH
```

---

## Private EKS — 7 VPC Endpoints: What Breaks Without Each

```
✅ s3        Gateway (FREE)  — ECR image layers stored in S3
✅ ec2       Interface       — nodeadm bootstrap + VPC CNI ENI management
✅ ecr.api   Interface       — image metadata
✅ ecr.dkr   Interface       — actual image pull
✅ eks       Interface       — Kubernetes API access
✅ sts       Interface       — token exchange (IRSA + internal)
✅ eks-auth  Interface       — Pod Identity Agent credentials

Miss → What breaks:
  ec2 missing    → nodeadm timeout, node never joins
  eks-auth miss  → CNI not initialized (node joins but NotReady)
  ecr.dkr miss   → ImagePullBackOff on all pods
  sts missing    → IRSA fails silently (403 from STS)
```
