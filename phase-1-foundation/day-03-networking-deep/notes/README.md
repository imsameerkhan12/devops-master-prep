# Day 3: Networking Deep — DevOps Lens

## OSI Model — Practical Mapping

| Layer | Name | Protocol | DevOps Relevance |
|-------|------|----------|-----------------|
| 3 | Network | IP | VPC, subnets, security groups, routing |
| 4 | Transport | TCP/UDP | NLB, SG port filtering |
| 7 | Application | HTTP/HTTPS | ALB, Ingress, Cloudflare WAF |

**Interview tip:** Name the layer → interviewer knows you understand networking.

---

## TCP vs UDP

| | TCP | UDP |
|-|-----|-----|
| Connection | Yes (3-way handshake) | No |
| Reliability | Guaranteed, ordered | Best-effort, unordered |
| Speed | Slower | Faster |
| Use cases | HTTP, SSH, DB | DNS, video streaming, gaming |

**3-way handshake:** SYN → SYN-ACK → ACK

**Common ports:**
- 22 SSH | 80 HTTP | 443 HTTPS | 53 DNS
- 3306 MySQL | 5432 Postgres | 6379 Redis

---

## DNS Deep Dive

### Record Types
| Record | Purpose | Example |
|--------|---------|---------|
| A | IPv4 address | `api.example.com → 1.2.3.4` |
| AAAA | IPv6 address | `api.example.com → ::1` |
| CNAME | Alias to another name | `www → api.example.com` |
| MX | Mail server | email routing |
| TXT | Verification, SPF, DKIM | domain ownership proof |
| NS | Authoritative nameserver | delegation |

### TTL Strategy
- Short TTL (60s) → frequent changes (migration, failover)
- Long TTL (24h) → stable records

### Resolution Flow
```
Browser → OS cache → ISP resolver → Root (.) → TLD (.com) → Authoritative → Answer
```

### Cloudflare
- **Orange cloud (Proxied):** CF is in path → DDoS protection + hides origin IP
- **Grey cloud (DNS-only):** Direct to origin, no CF protection

---

## HTTP Status Codes

| Range | Meaning | Key Codes |
|-------|---------|-----------|
| 2xx | Success | 200 OK |
| 3xx | Redirect | 301 permanent, 302 temp |
| 4xx | Client error | 401 auth, 403 forbidden, 404 not found, 429 rate limit |
| 5xx | Server error | 500 internal, 502 bad gateway, 503 unavailable, 504 timeout |

---

## TLS Handshake
```
Client → ClientHello (TLS version, cipher suites)
Server → ServerHello + Certificate
Client → Verify cert (CA chain) + Key exchange
Both  → Derive session key
Now   → Encrypted communication
```
Cert chain: Root CA → Intermediate CA → Domain cert

---

## Load Balancers: L4 vs L7

| | L4 (NLB) | L7 (ALB, Nginx, Cloudflare) |
|-|----------|---------------------------|
| Level | TCP/UDP | HTTP/HTTPS |
| Speed | Faster | Slower but smarter |
| Features | Port-level | Path routing, header manipulation, WAF |
| Use case | Raw throughput, TLS pass-through | Web apps, microservices |

**Sticky sessions:** Same client → same backend. Cookie or IP-based. Required for stateful apps.

---

## Subnetting + CIDR

| CIDR | Total IPs | Usable IPs |
|------|-----------|------------|
| /24 | 256 | 254 |
| /20 | 4,096 | 4,094 |
| /16 | 65,536 | 65,534 |
| /28 | 16 | 14 |

**Formula:** `2^(32 - prefix) - 2`

**AWS pattern:** VPC = /16, Subnets = /20 or /24

---

## 5 End-of-Day Q&A Answers

**1. DNS resolution flow:**
Browser cache → OS cache → ISP resolver → root nameserver → TLD (.com) → authoritative NS → answer → cached per TTL

**2. TCP vs UDP:**
TCP = reliable, ordered, connection-based (HTTP/SSH/DB). UDP = fast, unreliable, connectionless (DNS/streaming/gaming).

**3. L4 vs L7 LB:**
L4 = TCP/UDP level, fast, no HTTP inspection (NLB). L7 = HTTP-aware, path routing, WAF, header manipulation (ALB, Nginx).

**4. HTTPS/TLS handshake:**
ClientHello → ServerHello + cert → key exchange → encrypted session using derived symmetric key.

**5. /24 usable IPs:**
254. Formula: 256 total - 2 reserved (network address + broadcast).

---

## Hands-on Checklist
- [ ] `dig +trace google.com` — watch root → TLD → authoritative
- [ ] `curl -v https://api.github.com` — inspect TLS handshake in output
- [ ] `tcpdump -i any port 80 -A` — capture HTTP request
- [ ] Subnet calculator: given /22, how many /26 subnets? (Answer: 16)
