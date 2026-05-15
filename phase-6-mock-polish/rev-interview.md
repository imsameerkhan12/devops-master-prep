# Interview Cheatsheet
> STAR Stories · Q&A Rapid Fire · Hindi Analogies

---

## STAR Stories

**Format:** Situation → Task → Action → Result (numbers required, 2 min max)

| # | Story | Key Result |
|---|-------|-----------|
| 1 | **Vault → SSM Migration** (Compliance Innovation) | 50+ services, zero downtime, cost reduction |
| 2 | **Docker Compose → Helm** (Indicios) | Multi-env parity, reduced deploy time |
| 3 | **Production Incident** | Fill with real incident — RCA + resolution time |
| 4 | **Cross-team Disagreement** | GitOps proposal — dev access + security RBAC |
| 5 | **Database DevOps** (Victra) | SSDT + Azure DevOps, faster + fewer prod issues |
| 6 | **Why Leaving** (TokenTide) | Seeking larger scale + stronger engineering culture |

**Tell Me About Yourself (memorize):**
> "I'm a DevOps engineer with 5 years of experience across AWS, Kubernetes, and CI/CD. At Compliance Innovation I worked on secrets migration from Vault to AWS SSM using External Secrets Operator, and containerized workloads from Docker Compose to Helm on EKS. Before that at Cybage I built Database DevOps pipelines for a US telecom client using SSDT and Azure DevOps, and GraphQL gateways with HotChocolate. I hold the CKA and AZ-204. I'm looking for a role where I can work on platform engineering at scale."

---

## Q&A Rapid Fire

### K8s Internals

**Q: Pod is Pending — 5 debug steps?**
> 1. `kubectl describe pod` → Events section
> 2. Check node resources: `kubectl describe node`
> 3. Check for taints without tolerations
> 4. Check PVC: `kubectl get pvc`
> 5. Check image pull: might become ImagePullBackOff

**Q: Swap liveness and readiness — what happens?**
> Liveness as readiness = traffic to unready pods → errors for users.
> Readiness as liveness = any slow response = restart loop → OOMKill spiral.

**Q: StatefulSet vs Deployment — 4 differences?**
> 1. Stable pod names (pod-0) vs random. 2. Per-pod PVC vs shared. 3. Ordered start/stop vs parallel. 4. Headless DNS per pod vs single Service.

**Q: Why HPA needs metrics-server?**
> metrics-server aggregates pod CPU/memory from kubelets. HPA polls metrics-server every 15s.

**Q: Service not routing traffic — what do you check?**
> `kubectl get endpoints <svc>` — if empty, selector mismatch. If populated, check pod port vs service targetPort.

---

### AWS

**Q: IRSA vs node IAM role?**
> Node role = all pods share permissions = blast radius huge. IRSA = per-pod SA granularity, one pod compromised ≠ all pods. Audit trail per SA in CloudTrail.

**Q: SG vs NACL — key difference?**
> SG is stateful (return traffic auto-allowed), NACL is stateless (both directions explicit). SG is allow-only, NACL can deny. SG = instance level, NACL = subnet level.

**Q: VPC Gateway vs Interface endpoint?**
> Gateway = FREE, only S3/DynamoDB, route table entry. Interface = paid (ENI), all other AWS services. Both keep traffic within AWS network.

---

### Observability

**Q: Why `rate()` instead of raw counter?**
> Raw counter is meaningless alone — is 15,847 requests over 1 second or 1 year? `rate()` gives per-second rate. Counters always need `rate()`.

**Q: Cardinality explosion — what is it?**
> Every unique label combination = 1 time series in Prometheus. Adding user_id with 100K users = 1.5M+ series → Prometheus OOM crash.

**Q: RED vs USE?**
> RED = services (Rate/Errors/Duration). USE = infrastructure (Utilization/Saturation/Errors).

**Q: Error budget?**
> 1 - SLO. 99.9% SLO = 43.8 min downtime/month budget. Burn rate alerting = are we consuming budget too fast?

---

### IaC

**Q: Why OpenTofu over Terraform?**
> HashiCorp changed Terraform license to BSL in August 2023 — no longer open source. OpenTofu is the Linux Foundation fork, MPL 2.0, drop-in replacement with same HCL and state format.

**Q: `tofu state mv` vs `tofu import`?**
> `state mv` renames a resource in state (no destroy/recreate). `import` adds an existing real resource to state that was created outside Terraform.

**Q: S3 backend `use_lockfile` vs DynamoDB?**
> Old: DynamoDB table for state locking — extra resource, cost, maintenance. New (OpenTofu 1.8+): S3 native locking with conditional writes. No extra resource needed.

---

### CI/CD

**Q: OIDC vs static AWS keys in GitHub Actions?**
> Static keys = long-lived, leak risk, need rotation. OIDC = GitHub issues JWT, AWS STS verifies, temp creds valid 15 min. No keys stored anywhere.

**Q: `helm upgrade --atomic` — what does it do?**
> If upgrade fails or times out, automatically rolls back to previous revision. Prevents broken partial upgrades.

---

### GitOps

**Q: ArgoCD `prune` vs `selfHeal`?**
> `prune`: resource removed from Git → ArgoCD deletes from K8s. `selfHeal`: someone does `kubectl apply` manually → ArgoCD reverts it back to Git state.

---

## Conceptual Analogies — Hindi

### TCP 3-Way Handshake — Phone Call

```
Browser               Server
  |-------- SYN -------->|   "Connection chahiye"
  |<------ SYN-ACK ------|   "Ok ready hu — tu ready hai?"
  |-------- ACK -------->|   "Haan ready hu — shuru karte hain"
  |<=== Data flow ======>|   Ab actual data flow

Real life: "Bhai sun sakta hai?" → "Haan! Tu sun sakta hai?" → "Haan! Chal baat karte"
```

**Interview:** "TCP establishes reliable connection. SYN (client initiates), SYN-ACK (server confirms + asks back), ACK (client confirms). Only then data flows. UDP skips this — faster, no guarantee."

---

### DNS TTL — Fridge Analogy

```
Doodh ka packet fridge mein → "Use by: 3 din"
DNS cache            → "TTL = 3600 sec (1 ghanta)"

Browser → DNS se poocha → "google.com = 142.250.x.x, TTL=3600"
          1 ghante tak cache mein, dobara DNS se nahi poochega

Migration playbook:
  Step 1: TTL = 300 (2-3 din pehle set karo)
  Step 2: IP change karo
  Step 3: 5 min mein propagate → verify
  Step 4: TTL = 3600 wapas
```

**Interview:** "TTL defines how long resolvers cache a DNS record. Before migration I lower TTL to 5 minutes so the change propagates quickly. Once stable, I restore the long TTL."

---

### TLS Handshake — Paint Mixing

```
Step 1: ClientHello — "Main TLS 1.3 jaanta hu, ye ciphers support karta hu"
Step 2: Server sends Certificate (DigiCert se ID card)
Step 3: Client verifies CA chain, domain, expiry
Step 4: Key Exchange (Diffie-Hellman):

  Common color: YELLOW (public)
  Tu:           BLUE   (secret)
  Server:       RED    (secret)

  Tu bhejta hai:    Yellow+Blue  = GREEN  (public)
  Server bhejta:    Yellow+Red   = ORANGE (public)

  Tu leta hai:      Orange + Blue  = BROWN (session key)
  Server leta hai:  Green  + Red   = BROWN (same!)

  BROWN = Session Key — kisi ko nahi pata kaise bana
Step 5: Encrypted communication (AES-256)
```

**Interview:** "TLS 1.3 does handshake in 1 RTT. ECDH key exchange — both sides derive the same session key without transmitting it. All communication is symmetrically encrypted."

---

### CIDR — Apartment Building

```
Society: "Nehru Nagar" = VPC (10.0.0.0/16)
Building A: 10.0.1.0/24  — Public floors  — ALB, Bastion
Building B: 10.0.3.0/24  — Private floors — EKS nodes, RDS

/24 = 24 bits FIXED, 8 bits FREE → 2^8 = 256 addresses → 254 usable

| CIDR | Usable  |
|------|---------|
| /32  | 1       |
| /28  | 14      |
| /24  | 254 ★   |
| /16  | 65,534 ★|

Formula: 2^(32-prefix) - 2
```

**Interview:** "CIDR groups IPs so routers need only the network prefix. /24 gives 254 usable, /16 gives ~65,500. AWS recommends /16 for VPCs to have room across AZs."

---

### VPC — Gated Society

```
AWS = badi building (millions of servers)
VPC = tera apna gated society — baaki kisi ka traffic andar nahi

Internet Gateway = society ka main gate
NAT Gateway     = "courier boy" — andar wale bahar bhej sakte hain,
                  bahar wale seedha andar nahi aa sakte

Private EC2 SSH timeout = NOT security group — routing issue!
  Private subnet → no route to IGW → TCP never reaches instance
```

**Interview:** "Public and private subnets differ only in route table — public has 0.0.0.0/0 → IGW, private does not. SSH timeout on private EC2 is a routing issue, not a security group issue."

---

### K8s Objects — Hindi Picture

```
Internet
    │
Ingress (ALB) — traffic receive karta hai bahar se
    │
Service (ClusterIP) — pods ko group, load balance karta hai
    │
    ├── Pod 1 (Nginx)
    ├── Pod 2 (Nginx)
    └── Pod 3 (Nginx)
    ↑
Deployment — pods manage karta hai (desired state = 3)

Pod    = flat  (mortal — mara toh gaya)
Deployment = HR manager ("5 log chahiye" — gaya toh naya laao)
Service = stable address — pod IP changes, Service IP stays constant
```
