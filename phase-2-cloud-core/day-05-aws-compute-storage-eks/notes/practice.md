# Day 5 Practice Notes — EKS Architecture + IRSA Deep Dive

---

## 1. EKS — Control Plane vs Data Plane

### Hindi

```
Control Plane = EKS ka brain — AWS manage karta hai
Data Plane    = EKS ka body — tera kaam hai
```

```
Tu kubectl run karta hai
        │
        ▼
API Server (Control Plane — AWS)     ← request receive karta hai
        │
        ▼
Scheduler (Control Plane — AWS)      ← decide karta hai pod kaun se node pe jaaye
        │
        ▼
Worker Node (Data Plane — tera EC2)  ← pod actually yahan chalta hai
        │
        ▼
Pod → Nginx container → HTML page with S3 list
```

**AWS ka SLA:** Control plane ke liye AWS responsible — agar API server gaya toh AWS fix karega.
**Teri responsibility:** Worker nodes — patch karo, size sahi rakho, monitor karo.

### English — Interview Answer

> "In EKS, AWS manages the control plane — API server, etcd, scheduler, and controller manager — with a 99.95% SLA. My team is responsible for the data plane — worker nodes running as EC2 instances in my VPC. This separation means I never SSH into control plane components, never manage etcd backups, and never worry about API server upgrades — AWS handles all of that."

---

## 2. Node Groups — Managed vs Self-managed vs Fargate

### Hindi

```
Worker Nodes = EC2 instances jahan pods chalte hain
Node Group   = Ek set of same type EC2s
```

| Type | Kaun manage karta hai | Control | Use Case |
|---|---|---|---|
| **Managed Node Group** | AWS EC2 banata, patch karta, drain karta | Medium | Production standard |
| **Self-managed** | Tu banata, patch karta, drain karta | Full | Custom AMI chahiye |
| **Fargate** | Node hi nahi — sirf pods | Minimum | Batch jobs, bursty workloads |

**Analogy:**

| Type | Analogy |
|---|---|
| Managed Node Group | Company car — company maintain karti hai, tu sirf drive karta hai |
| Self-managed | Apni car — sab kuch tera zimma |
| Fargate | Uber — car ki tension nahi, sirf destination batao |

**Node Group ke andar:**
```
Node Group
    │
    ├── Launch Template (EC2 config — AMI, instance type, storage)
    ├── Auto Scaling Group (min/max/desired nodes)
    └── EC2 Instances (actual worker nodes)
             │
             └── Pods run here
```

**Hamare project mein:** Managed Node Group — production standard.

### English — Interview Answer

> "I prefer Managed Node Groups in production. AWS handles the underlying EC2 lifecycle — provisioning, patching AMIs, and gracefully draining nodes during cluster upgrades. With self-managed nodes you get more control — custom AMIs, custom kubelet flags — but the operational burden is much higher. Fargate is good for batch jobs or bursty workloads where you don't want to manage node capacity, but it doesn't support DaemonSets and has some networking limitations."

---

## 3. VPC CNI — Pod Networking

### Hindi

**Normal K8s — overlay network:**
```
Pod IP: 192.168.1.5  ← fake IP, sirf cluster ke andar
Node IP: 10.0.1.10   ← real VPC IP
Traffic: Pod → Node → NAT → destination  (extra hop)
```

**AWS VPC CNI — real VPC IPs:**
```
Pod IP: 10.0.3.45   ← real VPC IP
Node IP: 10.0.3.10  ← real VPC IP
Pod directly reachable hai VPC ke andar — no NAT
```

**Kaise kaam karta hai:**
```
Worker Node (EC2: t3.medium)
    │
    ├── Primary ENI       → Node ka IP (10.0.3.10)
    └── Secondary ENI(s)  → Pod IPs (10.0.3.45, 10.0.3.46...)
         └── Har ENI pe multiple IPs — pods ke liye
```

**ENI = Elastic Network Interface** = EC2 ka virtual network card

**Pod Density Limit — important:**
```
t3.medium = max 3 ENIs × 6 IPs = 16 pods max
t3.large  = max 3 ENIs × 12 IPs = 34 pods max
```

**Interview gotcha:** Node size choose karte waqt sirf CPU/RAM nahi — max pods per node bhi dekho.

### English — Interview Answer

> "AWS VPC CNI assigns real VPC IP addresses to each pod by attaching secondary ENIs to worker nodes. This means pods are first-class citizens in the VPC — they can communicate directly with RDS, ElastiCache, or any VPC resource without NAT. The trade-off is pod density — each node has a limit on ENIs and IPs based on instance type, so you need to size nodes carefully."

---

## 4. kubectl + kubeconfig

### Hindi

```
kubectl    = Command line tool — K8s se baat karne ka ek hi tarika
kubeconfig = Config file — kubectl ko batata hai KAHAN connect karo aur KAUN ho tum

Analogy:
kubectl    = Phone
kubeconfig = Phone book — number, password, kaun se network
```

**Default location:** `~/.kube/config`

**EKS mein kubeconfig kaise milti hai:**
```bash
aws eks update-kubeconfig --region us-east-1 --cluster-name my-eks-cluster
kubectl get nodes  # verify
```

**Under the hood:**
```
kubectl get nodes
    │
    ▼
kubeconfig → EKS API Server URL milta hai
    │
    ▼
AWS CLI se token leta hai (aws eks get-token)
    │
    ▼
Token + request → EKS API Server → IAM verify → response
```

**Multiple clusters — context switching:**
```bash
kubectl config get-contexts          # sab contexts dekho
kubectl config use-context prod      # switch karo
kubectl config current-context       # verify — prod pe ho?
```

**Common commands:**
```bash
kubectl get nodes
kubectl get pods -A                          # sab namespaces
kubectl get pods -n kube-system
kubectl exec -it <pod-name> -- /bin/bash
kubectl logs <pod-name> -f                   # live logs
kubectl logs <pod-name> --previous           # crashed pod logs
kubectl describe pod <pod-name>
kubectl apply -f deployment.yaml
kubectl delete -f deployment.yaml
```

### English — Interview Answer

> "kubectl reads the kubeconfig file — by default at ~/.kube/config — which contains the cluster endpoint, authentication method, and current context. For EKS, authentication works through IAM — kubectl calls aws eks get-token under the hood, which returns a pre-signed URL that EKS validates against IAM. In environments with multiple clusters, I use kubectl config use-context to switch — and I always verify current-context before running any destructive commands in production."

---

## 5. K8s Objects — Pod, Deployment, Service, Ingress

### Hindi — Full Picture

```
Internet
    │
    ▼
Ingress (ALB)          ← Traffic receive karta hai bahar se
    │
    ▼
Service (ClusterIP)    ← Pods ko group karta hai, load balance karta hai
    │
    ├── Pod 1 (Nginx)
    ├── Pod 2 (Nginx)
    └── Pod 3 (Nginx)
    ↑
Deployment             ← Pods manage karta hai — desired state
```

---

### Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
```

**Analogy:** Pod = Flat. Container = flat mein rehne wala banda.
**Important:** Pod directly production mein use nahi karte — mortal hai. Mara toh gaya. Deployment use karo.

---

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

**Deployment kya karta hai:**
- Pod mara → naya banao automatically
- Node gaya → doosre node pe schedule karo
- Image update → rolling update (zero downtime)

**Analogy:** Deployment = HR manager. "5 employees chahiye" — ek gaya toh naya dhoondho.

---

### Rolling Updates

```
Purana: nginx:1.0 (3 pods)
Naya:   nginx:2.0

Step 1: Pod 1 → 2.0 ✅ | Pod 2 → 1.0 | Pod 3 → 1.0
Step 2: Pod 1 → 2.0 ✅ | Pod 2 → 2.0 ✅ | Pod 3 → 1.0
Step 3: Pod 1 → 2.0 ✅ | Pod 2 → 2.0 ✅ | Pod 3 → 2.0 ✅
Zero downtime ✅
```

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1   # ek waqt mein kitne down ho sakte hain
    maxSurge: 1         # kitne extra pods temporarily ban sakte hain
```

```bash
kubectl rollout undo deployment/nginx-deployment           # rollback
kubectl rollout history deployment/nginx-deployment        # history
kubectl rollout undo deployment/nginx-deployment --to-revision=2
```

---

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

**Problem jo Service solve karta hai:**
```
Pod IPs change hoti hain restart pe:
  Pod 1: 10.0.3.45 → restart → 10.0.3.67 (changed)

Service IP hamesha same:
  Service: 10.96.0.1 ← ye use karo
```

| Type | Kaam | Use Case |
|---|---|---|
| ClusterIP | Sirf cluster ke andar | Internal communication |
| NodePort | Node IP + port | Testing only |
| LoadBalancer | AWS ELB banata hai | Production (but Ingress better) |

---

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
```

**Ingress vs LoadBalancer Service:**
```
LoadBalancer Service:
  Service A → ALB 1 ($$$)
  Service B → ALB 2 ($$$)

Ingress (1 ALB):
  ALB → /api   → Service A  ✅ sasta
      → /app   → Service B
```

### English — Interview Answer

> "In Kubernetes, a Pod is the smallest deployable unit. In production, we never deploy bare pods — we use Deployments which maintain desired replica count, handle rolling updates, and reschedule pods on node failures. Services provide stable network endpoints — since pod IPs change on restart, a Service's ClusterIP stays constant. Ingress handles external HTTP/HTTPS traffic — with AWS Load Balancer Controller, an Ingress resource automatically provisions an ALB, allowing you to route traffic to multiple services through a single load balancer."

---

## 6. AWS Load Balancer Controller

### Hindi

```
Problem:
  Ingress YAML banaya — bas definition hai
  Koi actually ALB nahi bana

AWS LB Controller:
  EKS ke andar ek pod chalta hai
  Ingress resource dekha → AWS API call → ALB banaya
```

**Analogy:**
> Ingress = Blueprint — "Mujhe ek darwaza chahiye"
> AWS LB Controller = Contractor — blueprint dekha, darwaza laga diya

**Full Flow:**
```
kubectl apply -f ingress.yaml
    │
    ▼
AWS LB Controller ne dekha — naya Ingress
    │
    ▼
AWS API:
  ALB create → Target Group banao → Listener add → Rules set
    │
    ▼
ALB ready → DNS name milti hai
    │
    ▼
Browser → ALB DNS → Target Group → Pod
```

**IRSA use karta hai — node IAM role nahi:**
```
aws-load-balancer-controller pod
    │ IRSA
    ▼
IAM Role: AWSLoadBalancerControllerIAMPolicy
    │
    ▼
AWS API: elasticloadbalancing:*, ec2:*, ...
```

**Instance vs IP target type:**
```
Instance mode: Browser → ALB → Node:NodePort → kube-proxy → Pod (extra hop)
IP mode:       Browser → ALB → Pod IP directly (fast, recommended)
```

### English — Interview Answer

> "AWS Load Balancer Controller runs inside the EKS cluster and watches for Ingress and Service resources. When you create an Ingress, it automatically provisions an ALB with correct listeners, target groups, and routing rules. It uses IRSA for AWS API access. I always use target-type: ip with VPC CNI because it routes traffic directly to pod IPs, bypassing the extra kube-proxy hop — better performance and cleaner connection tracking."

---

## 7. IRSA — Full Deep Dive

### Hindi — Problem

```
Without IRSA:
Node IAM Role → sab pods share karte hain
Pod 1 (Nginx)       → S3 access ✅
Pod 2 (Payment)     → S3 access ✅
Pod 3 (Logger)      → S3 access ✅ (zaroorat nahi thi!)
Pod 4 (Hacked)      → S3 access ✅ 💀 PROBLEM

With IRSA:
Pod 1 (Nginx + S3)  → Sirf s3:ListBucket
Pod 2 (Payment)     → Sirf DynamoDB
Pod 3 (Logger)      → Koi AWS permission nahi
Pod 4 (Hacked)      → Koi permission nahi — blast radius = zero ✅
```

### IRSA Flow — 5 Steps

```
STEP 1 — EKS OIDC Provider
  EKS cluster ka OIDC URL:
  https://oidc.eks.us-east-1.amazonaws.com/id/XXXXX
  AWS IAM ko batata hai: "Is cluster ke tokens pe trust karo"

STEP 2 — IAM Role banao
  Trust Policy:
  {
    "Principal": {
      "Federated": "arn:aws:iam::123:oidc-provider/oidc.eks..."
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.../id/XXX:sub":
        "system:serviceaccount:default:s3-reader-sa"
      }
    }
  }
  Permission Policy: s3:ListBucket

STEP 3 — K8s ServiceAccount banao (TU banata hai — kubectl se)
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: s3-reader-sa
    namespace: default
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123:role/s3-reader-role

STEP 4 — Pod mein ServiceAccount specify karo
  spec:
    serviceAccountName: s3-reader-sa   ← bas itna
  
  Automatically mount hota hai:
  /var/run/secrets/eks.amazonaws.com/serviceaccount/token (JWT)

STEP 5 — AWS SDK magic
  Pod mein:
    import boto3
    s3 = boto3.client('s3')
    s3.list_buckets()
  
  SDK automatically:
    1. Token file padhta hai
    2. STS AssumeRoleWithWebIdentity call karta hai
    3. Temp credentials milti hain (15 min expiry)
    4. S3 call hoti hai ✅
```

**Environment variables jo auto-set hote hain:**
```bash
AWS_ROLE_ARN=arn:aws:iam::123456:role/s3-reader-role
AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token
# AWS SDK in dono ko dekh ke automatically AssumeRoleWithWebIdentity karta hai
```

**SA mount manually nahi karna — bas serviceAccountName specify karo:**
```yaml
spec:
  serviceAccountName: s3-reader-sa  # bas itna — baaki sab automatic
```

**Agar serviceAccountName nahi likha:**
- Pod `default` SA se run karega
- Koi IAM role nahi → AWS API calls fail

### English — Interview Answer

> "IRSA gives individual Kubernetes pods their own AWS IAM identity without sharing the node's IAM role. It works through OIDC federation. EKS exposes an OIDC provider endpoint, and you create an IAM role whose trust policy is scoped to a specific namespace and service account. When a pod runs with that service account, EKS automatically mounts a signed JWT token into the pod. The AWS SDK detects AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE environment variables and automatically calls STS AssumeRoleWithWebIdentity to exchange the JWT for short-lived credentials. No credential management, no rotation — fully automatic. At TokenTide, I used IRSA for every pod that needed AWS access — ESO pods for Secrets Manager, app pods for S3, and the Load Balancer Controller for ALB provisioning."

---

## 8. Pod Identity — IRSA ka Modern Alternative

### Hindi — Kya hai

```
Same goal: Pod ko AWS IAM permissions dena
IRSA      = OIDC federation → STS → temp credentials (complex setup)
Pod Identity = Agent based → simpler setup, same result
```

**IRSA vs Pod Identity:**

| | IRSA | Pod Identity |
|---|---|---|
| Mechanism | OIDC → STS AssumeRoleWithWebIdentity | Pod Identity Agent (daemonset) |
| Setup | Complex — OIDC provider + trust policy | Simple — direct association |
| Cross-account | ✅ Supported | ❌ Same account only |
| EKS version | All versions | 1.24+ |
| Best for | Multi-account, complex | Simple same-account |

### Pod Identity Flow

```
STEP 1 — Pod Identity Agent install karo (add-on — already selected)
  EKS ke andar daemonset chalta hai har node pe

STEP 2 — IAM Role banao
  Trust Policy mein pods.eks.amazonaws.com principal
  {
    "Principal": {
      "Service": "pods.eks.amazonaws.com"
    },
    "Action": [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
  Permission Policy: s3:ListBuckets

STEP 3 — Pod Identity Association banao (AWS side)
  EKS → Cluster → Access → Pod Identity Associations
  IAM Role + Namespace + ServiceAccount name specify karo

STEP 4 — K8s ServiceAccount banao (annotation nahi chahiye!)
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: s3-reader-sa
    namespace: default
  # No annotation needed — Pod Identity handles it

STEP 5 — Pod mein ServiceAccount specify karo
  spec:
    serviceAccountName: s3-reader-sa

STEP 6 — Pod Identity Agent magic
  Pod start hota hai
      │
      ▼
  Agent intercept karta hai credentials request
      │
      ▼
  AWS se temp credentials fetch karta hai
      │
      ▼
  Pod ko inject karta hai — AWS SDK use karta hai automatically
```

**Key difference from IRSA:**
```
IRSA:         SA pe annotation chahiye + OIDC provider setup
Pod Identity: Koi annotation nahi — association AWS side pe hoti hai
              Clean separation — K8s objects AWS se decouple hote hain
```

### English — Interview Answer

> "Pod Identity is the newer, simpler alternative to IRSA for granting AWS permissions to EKS pods. Instead of OIDC federation, it uses a Pod Identity Agent daemonset that runs on each node. You create an IAM role with pods.eks.amazonaws.com as the trusted service, then create a Pod Identity Association in EKS linking the role to a specific namespace and service account. No annotation on the ServiceAccount is needed — AWS manages the association separately, keeping Kubernetes objects clean and decoupled from AWS-specific configuration. The limitation is it only works for same-account access — for cross-account scenarios IRSA is still needed."

---

## 9. Ingress — Traefik (Cloud Agnostic Standard)

### Hindi — Kyu Traefik

```
AWS LB Controller  = AWS only — vendor lock-in
Nginx Ingress      = Deprecated ho raha hai
Traefik            = Cloud agnostic, Gateway API support, production standard
Kubernetes Gateway API = Official K8s future standard (Ingress ka replacement)
```

**Traefik = Gateway API implement karta hai — portable, modern**

```
Hamare app mein:
Browser
    │
    ▼
AWS NLB (Traefik ne banaya — LoadBalancer Service)
    │
    ▼
Traefik (Ingress Controller)
    │
    ▼
HTTPRoute (Gateway API resource)
    │
    ▼
Service → Nginx Pods
```

---

## 10. Our App — S3 Bucket Lister

**What we are building:**
```
Browser
    │
    ▼
NLB → Traefik (Gateway API)
    │
    ▼
Service (ClusterIP)
    │
    ▼
Nginx Pod
    │
    ├── HTML page serve karta hai
    └── S3 API call (Pod Identity se credentials — no hardcoding)
         │
         ▼
        S3 bucket list → HTML mein show karo
```

**K8s objects needed:**
```
1. ServiceAccount     → s3-reader-sa (no annotation needed — Pod Identity)
2. Deployment         → nginx pods (2 replicas)
3. Service            → ClusterIP
4. Gateway + HTTPRoute → Traefik se bahar expose karo
```

**4 Phases of implementation:**
```
Phase 1 — Console   → AWS Console se cluster + app deploy
Phase 2 — CLI       → eksctl + kubectl se same
Phase 3 — IaC       → Terraform se poora cluster + app
```

---

## 11. EKS Cluster — Hands-on Log (Console)

### IAM Roles Created

| Role | Purpose | Policies |
|---|---|---|
| `devops-lab-eks-cluster-role` | EKS Control Plane | AmazonEKSClusterPolicy |
| `devops-lab-eks-node-role` | Worker Nodes | AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly |
| `AmazonEKSPodIdentityAmazonEBSCSIDriverRole` | EBS CSI Driver (Pod Identity) | AmazonEBSCSIDriverPolicy |
| `AmazonEKSPodIdentityAmazonVPCCNIRole` | VPC CNI (Pod Identity) | AmazonEKS_CNI_Policy |

### Cluster Configuration

| Setting | Value | Why |
|---|---|---|
| Name | `devops-lab-eks` | |
| K8s Version | `1.33` | n-1 stable — 1.35 bleeding edge |
| EKS Auto Mode | Disabled | Manual control — learning |
| Cluster Role | `devops-lab-eks-cluster-role` | Control plane AWS API access |
| VPC | `devops-lab-vpc` | Dedicated VPC — not default |
| Subnets | 2 private subnets | Nodes private mein — best practice |
| Endpoint | Public and Private | kubectl bahar se + nodes VPC ke andar |
| Auth Mode | EKS API | Modern — aws-auth ConfigMap legacy hai |
| Control Plane Logs | API server + Audit ON | Security + debugging |
| Deletion Protection | OFF | Lab — easy cleanup |

### Add-ons Selected

| Add-on | Why |
|---|---|
| Amazon VPC CNI | Pod networking — real VPC IPs |
| kube-proxy | Service networking |
| CoreDNS | Cluster DNS |
| Amazon EBS CSI Driver | Persistent storage |
| Amazon EKS Pod Identity Agent | Pod Identity — modern IRSA alternative |
| Metrics Server | HPA — autoscaling |

### Node Group Configuration ✅

| Setting | Value | Why |
|---|---|---|
| Name | `devops-lab-node-group` | |
| Node IAM Role | `devops-lab-eks-node-role` | Nodes ko cluster join + ECR pull permission |
| AMI | Amazon Linux 2023 x86_64 | EKS optimized — AWS maintain karta hai |
| Capacity | On-Demand | Lab — Spot kabhi bhi terminate ho sakta hai |
| Instance | `t3.medium` | 2 vCPU, 4GB RAM, 17 pods max — lab sweet spot |
| Disk | 20 GiB | Default kaafi hai |
| Desired/Min/Max | 1/1/1 | Lab — cost bachao |
| Subnets | 2 private subnets | Nodes always private mein |
| Remote access | OFF | SSH mat karo nodes pe — Session Manager use karo |
| Auto repair | Enabled | Node unhealthy → auto replace — free feature |

### Capacity Types — On-Demand vs Spot

| | On-Demand | Spot |
|---|---|---|
| Cost | Full price | 70-90% cheaper |
| Availability | Guaranteed | AWS kabhi bhi terminate kar sakta hai |
| Use case | Production, stateful | Batch jobs, stateless, dev |

**Production best practice:** On-Demand baseline + Spot for burst — Karpenter se mix karo

### Labels vs Taints

```
Label  = Pod node ko prefer karta hai (pull)
         nodeSelector: gpu: "true" → sirf GPU node pe jao

Taint  = Node pod ko reject karta hai (push away)
         taint: gpu=true:NoSchedule → normal pods yahan nahi aayenge
                                       sirf tolerating pods aayenge

Use case: GPU nodes pe sirf ML pods — costly nodes waste na ho
```

### Tools Installed — Windows Setup

| Tool | Version | Install Command | Kyu |
|---|---|---|---|
| kubectl | v1.36.0 | `choco install kubernetes-cli` | K8s CLI — cluster se baat karo |
| helm | v4.1.4 | `choco install kubernetes-helm` | Package manager — Traefik install |
| aws cli | v2.34.44 | `choco install awscli` | AWS API — cluster connect |
| kubectx | - | `choco install kubectx` | Fast cluster/namespace switching |
| kustomize | v5.8.1 | kubectl ke saath built-in | Base + overlay environment management |

**Kustomize kya hai:**
```
Same app — 3 environments (dev, staging, prod)
Base YAML ek — common config
Overlay — sirf jo alag hai wo likho (replicas, image tag)

Helm vs Kustomize:
  Helm       = Third party apps install (Traefik, Prometheus)
  Kustomize  = Apne apps ke environments manage karo
  Production = Dono saath use karte hain
```

### AWS Profile Setup (next step)

```powershell
# Named profile — best practice (default overwrite nahi hoga)
aws configure --profile devops-lab

# Fill karo:
# AWS Access Key ID
# AWS Secret Access Key
# Region: us-east-1
# Output format: json

# Use karo:
$env:AWS_PROFILE = "devops-lab"
# Ya har command mein:
aws eks update-kubeconfig --profile devops-lab --region us-east-1 --cluster-name devops-lab-eks
```

### VPC Endpoints — Full List (Private Cluster ke liye mandatory)

**Problem:** Private subnet mein nodes hain, NAT Gateway nahi — koi bhi AWS service reach nahi hogi.

**Solution — VPC Interface Endpoints (NAT Gateway se behtar):**
```
NAT Gateway  = $0.045/hr + $0.045/GB data — expensive, public internet se traffic jaata hai
VPC Endpoints = Direct AWS private network — cheaper + more secure
```

**Final list — 6 endpoints banaye (ek ek ka reason neeche):**

| Endpoint | Service Name | Type | Kyu Zaroor hai |
|---|---|---|---|
| S3 | `com.amazonaws.us-east-1.s3` | Gateway (FREE) | ECR image layers S3 se pull hoti hain |
| EKS API | `com.amazonaws.us-east-1.eks` | Interface | Nodes ko EKS control plane se baat karni hai |
| ECR API | `com.amazonaws.us-east-1.ecr.api` | Interface | Container image metadata |
| ECR Docker | `com.amazonaws.us-east-1.ecr.dkr` | Interface | Actual image pull |
| EC2 | `com.amazonaws.us-east-1.ec2` | Interface | nodeadm bootstrap + VPC CNI ENI management |
| EKS Auth | `com.amazonaws.us-east-1.eks-auth` | Interface | Pod Identity Agent credentials fetch |
| STS | `com.amazonaws.us-east-1.sts` | Interface | Token exchange (IRSA + some internal calls) |

**Config — har Interface endpoint ke liye:**
- VPC: `vpc-0b3ef75987ebd61cf`
- Subnets: `subnet-0da15a099f010105f` + `subnet-09d8c3b1f7ef7c079` (dono private)
- Security Group: `sg-02ccb2dda4ce17820` (EKS cluster SG — self-referencing allow all)
- Private DNS: **Enabled** (critical — warna public IP resolve hoti hai)

---

### Debugging Journey — Node Join Failure (Real Incident Log)

#### Problem 1: nodeadm `EC2:DescribeInstances` timeout

**Symptom:** Node group CREATING mein stuck — 40+ minute ho gaye, ACTIVE nahi hua.

**Debug kaise kiya:**
```powershell
# EC2 console output dekha — node ka bootstrap log
aws ec2 get-console-output --instance-id i-0d0adca32e3e6e342 --latest --output text
```

**Root cause:**
```
[   36s] nodeadm: retrying request EC2/DescribeInstances, attempt 2
[   67s] nodeadm: retrying request EC2/DescribeInstances, attempt 3
...
[  606s] nodeadm: context deadline exceeded  ← 10 min baad fail
[FAILED] nodeadm-co.service — EKS Nodeadm Config
```

`nodeadm` (AL2023 ka bootstrap tool) apna instance metadata `EC2:DescribeInstances` se fetch karta hai.
`ec2` VPC endpoint nahi tha → no internet → timeout → node never registered.

**Fix:** `com.amazonaws.us-east-1.ec2` endpoint create kiya → purana node terminate kiya → ASG ne naya banaya → nodeadm 0.85s mein complete.

---

#### Problem 2: CNI not initialized (Node registered but NotReady)

**Symptom:** New node ne cluster join kiya — `kubectl get nodes` mein tha — but `NotReady`.

**Node condition:**
```
Ready: False
cni plugin not initialized — NetworkPluginNotReady
```

**Debug kaise kiya:**
```powershell
# aws-node pod ke env vars check kiye
kubectl get pod -n kube-system aws-node-xxx -o jsonpath='{.spec.containers[0].env}' | ConvertFrom-Json
```

**Key finding:**
```
AWS_CONTAINER_CREDENTIALS_FULL_URI     = http://169.254.170.23/v1/credentials
AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE = /var/run/secrets/pods.eks.amazonaws.com/...
```

`aws-node` Pod Identity se credentials le raha tha (IMDS se nahi). Pod Identity Agent ko `eks-auth.us-east-1.api.aws` pe call karna tha credentials ke liye.

```powershell
# Pod Identity Agent logs dekhe
kubectl logs -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent
```

**Root cause:**
```
Post "https://eks-auth.us-east-1.api.aws/...": dial tcp 18.211.73.56:443: i/o timeout
                                                                ^^^^^^^^^
                                                                Public IP — internet chahiye
```

`eks-auth` VPC endpoint nahi tha → Pod Identity Agent `eks-auth.us-east-1.api.aws` reach nahi kar pa raha → aws-node ko credentials nahi mili → EC2 API calls fail → IPAM daemon start nahi hua → CNI initialize nahi hua.

**Fix:** `com.amazonaws.us-east-1.eks-auth` endpoint create kiya → Pod Identity Agent + aws-node restart → node Ready ✅

---

#### Problem 3: kubectl credentials — EKS Access Entry

**Symptom:**
```
error: You must be logged in to the server (the server has asked for the client to provide credentials)
```

**Root cause:** Cluster Console (root account) ne create kiya tha. `sameer` IAM user cluster mein authorized nahi tha.

**EKS 1.33 mein fix — Access Entries (modern way, aws-auth ConfigMap ka replacement):**
```powershell
# Access entry banao
aws eks create-access-entry --cluster-name devops-lab-eks \
  --principal-arn arn:aws:iam::271169999916:user/sameer \
  --type STANDARD

# Cluster admin policy attach karo
aws eks associate-access-policy --cluster-name devops-lab-eks \
  --principal-arn arn:aws:iam::271169999916:user/sameer \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

---

### kubectl Connect — Final Working Commands

```powershell
$env:PATH = $env:PATH + ";C:\Program Files\Amazon\AWSCLIV2"
$env:AWS_PROFILE = "sameer"

# kubeconfig update karo
aws eks update-kubeconfig --profile sameer --region us-east-1 --name devops-lab-eks

# verify
kubectl get nodes
kubectl get pods -n kube-system
```

**Final cluster state — healthy ✅**
```
NAME                           STATUS   ROLES    AGE   VERSION
ip-10-0-154-163.ec2.internal   Ready    <none>   32m   v1.33.11-eks-4136f65

kube-system pods:
aws-node-bn2f2                  2/2     Running   ← VPC CNI
coredns (x2)                    1/1     Running   ← DNS
ebs-csi-controller (x2)         6/6     Running   ← Storage
ebs-csi-node                    3/3     Running
eks-pod-identity-agent          1/1     Running   ← Pod Identity
kube-proxy                      1/1     Running
metrics-server (x2)             1/1     Running
```

---

### Lessons Learned — Private EKS Cluster Checklist

> **Interview gold:** "Private EKS cluster sirf 3 endpoints se nahi chalta — minimum 7 chahiye. Humne ek ek endpoint ki zaroorat debug karke seekhi."

```
Private EKS cluster ke liye mandatory VPC endpoints:
✅ s3         (Gateway — free)       — ECR image layers
✅ ecr.api    (Interface)            — image metadata
✅ ecr.dkr    (Interface)            — image pull
✅ eks        (Interface)            — Kubernetes API
✅ ec2        (Interface)            — nodeadm + VPC CNI
✅ eks-auth   (Interface)            — Pod Identity Agent
✅ sts        (Interface)            — token exchange

Miss karo toh:
  ec2 missing    → node never joins (nodeadm timeout)
  eks-auth missing → CNI not initialized (node registers but NotReady)
  sts missing    → IRSA fails silently
```

---

### Console vs CLI — Learning Value

```
Console (Phase 1) — time consuming but:
  ✅ Har setting ka matlab samjha
  ✅ Visually dekha kya ho raha hai
  ✅ Errors se seekha — real debugging experience

CLI (Phase 2) — ek command mein sab:
  eksctl create cluster \
    --name devops-lab-eks \
    --region us-east-1 \
    --nodegroup-name devops-lab-node-group \
    --node-type t3.medium \
    --nodes 1 \
    --private-networking  # handles endpoints automatically

IaC (Phase 3) — Terraform se repeatable, version controlled
```

### Next Steps

```
✅ Cluster Active
✅ Node Ready
✅ kubectl connected (sameer profile)
✅ All system pods running

Baaki karna hai:
1. Traefik install karo — Helm se
2. Pod Identity Association banao — S3 access ke liye (app ke liye)
3. S3 bucket create karo — list karne ke liye kuch toh chahiye
4. App deploy karo — Nginx + S3 lister
5. Test karo — browser se
6. CLEANUP — cluster + node group delete karo ($0.10/hr control plane + EC2 cost)
```

---

## Concept Summary

| Concept | Key Point |
|---|---|
| Control Plane | AWS manages — API server, etcd, scheduler |
| Data Plane | Tera kaam — worker nodes (EC2) |
| Managed Node Group | AWS patches, drains — production standard |
| VPC CNI | Real VPC IPs to pods — no overlay, no NAT |
| ENI | Elastic Network Interface — EC2 ka virtual NIC |
| kubectl | K8s CLI — kubeconfig se cluster choose karta hai |
| Pod | Smallest unit — mortal, directly deploy mat karo |
| Deployment | Pod manager — replicas, rolling updates, rollback |
| Service | Stable endpoint — pod IPs change, service IP fixed |
| Traefik | Cloud-agnostic ingress — Gateway API implement karta hai |
| Gateway API | K8s official future — Ingress ka replacement |
| IRSA | Per-pod IAM — OIDC federation, cross-account support |
| Pod Identity | Simpler IRSA alternative — same account, no SA annotation |
| ServiceAccount | Tu banata hai kubectl se — pod mein mount automatic |
