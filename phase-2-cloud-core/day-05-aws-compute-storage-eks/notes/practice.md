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

## 8. Our App — S3 Bucket Lister

**What we are building:**
```
Browser
    │
    ▼
ALB (Ingress — internet-facing)
    │
    ▼
Service (ClusterIP)
    │
    ▼
Nginx Pod
    │
    ├── HTML page serve karta hai
    └── S3 API call (IRSA se credentials — no hardcoding)
         │
         ▼
        S3 bucket list → HTML mein show karo
```

**K8s objects needed:**
```
1. ServiceAccount  → s3-reader-sa (IRSA annotated)
2. Deployment      → nginx pods (2 replicas)
3. Service         → ClusterIP (pods group karo)
4. Ingress         → ALB se bahar expose karo
```

**3 Phases of implementation:**
```
Phase 1 — Console   → AWS Console se cluster banao, visually samjho
Phase 2 — CLI       → eksctl + kubectl se same cheez karo
Phase 3 — IaC       → Terraform se poora cluster + app
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
| Ingress | HTTP routing — 1 ALB for multiple services |
| AWS LB Controller | Ingress → actual ALB banata hai (IRSA use karta hai) |
| IRSA | Per-pod IAM identity — OIDC federation via STS |
| ServiceAccount | Tu banata hai kubectl se — pod mein mount automatic |
