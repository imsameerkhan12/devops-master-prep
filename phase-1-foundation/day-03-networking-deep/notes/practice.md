# Day 3 Hands-on Practice Notes — Networking Deep

---

## 1. TCP 3-Way Handshake

```
Tera browser          Google ka server
     |                      |
     |-------- SYN -------->|   "Connection chahiye"
     |                      |
     |<------ SYN-ACK ------|   "Ok, ready hu. Tu ready hai?"
     |                      |
     |-------- ACK -------->|   "Haan ready hu. Shuru karte hain"
     |                      |
     |<=== Data flow ======>|   Ab actual data aana jaana shuru
```

### Real-life analogy — Phone call:

| Step | Real Life | Network |
|------|-----------|---------|
| SYN | "Bhai sun sakta hai mujhe? Baat karna chahta hu!" | Client requests connection |
| SYN-ACK | "Haan sun sakta hu! Aur tu sun sakta hai mujhe?" | Server confirms + asks back |
| ACK | "Haan teri awaaz aa rahi hai. Chal baat karte hain!" | Client confirms — connection ready |

---

## 2. DNS TTL — Time To Live

### Simple explanation — Fridge analogy

Tune doodh ka packet fridge mein rakha. Uspe likha hai **"Use by: 3 din"** — 3 din baad naya lana padega.

**DNS TTL = Exactly yehi concept.**

```
Browser ne DNS se poocha → "google.com = 142.250.x.x, TTL = 3600 sec"
Browser ne cache kiya    → "1 ghante tak dobara DNS se nahi poochunga"
1 ghanta baad            → TTL expire → phir se DNS se poochega
```

**Fayda:** Har baar DNS server se poochna nahi padta → fast load, kam traffic.

---

### TTL Strategy

| TTL | Use When |
|-----|----------|
| **Short (60s – 5 min)** | Migration se pehle, deployment, testing, incident mein fast redirect |
| **Long (1hr – 24hr)** | Stable production, CDN records, MX records |

### Production Playbook

```
Normal time       →  TTL = 3600 (1 ghanta)   — stable, fast
        ↓
Migration plan    →  TTL = 300 (5 min)        — 2-3 din pehle set karo
        ↓
Migration karo    →  IP change karo
        ↓
5 min mein propagate → verify karo
        ↓
Stable ho gaya    →  TTL = 3600 wapas
```

### Cloudflare

| Mode | TTL |
|------|-----|
| Proxied (orange cloud ON) | Auto 300 sec — Cloudflare controls |
| DNS Only (grey cloud) | Manual set kar sakte ho — production pe 3600 rakho |

### Interview Answer

> "TTL DNS cache ki expiry hai — kitni der tak purana IP valid hai. Migration ke time hum TTL pehle se kam kar dete hain taaki IP change hone ke baad fast propagation ho. Normal production mein TTL high rakhte hain taaki DNS load kam ho aur resolution fast ho."

---

## 3. TLS Handshake — Bank analogy

**Scene:** Tu ek bank mein jaata hai — kisi ko sune bina secret baat karni hai.

### Step 1 — ClientHello: "Tu bank mein ghusta hai"

Tu receptionist se kehta hai — *"Mujhe secure baat karni hai. Main TLS 1.2 ya 1.3 mein baat kar sakta hu."*

```
Browser bolta hai:
  - "Main TLS 1.3 jaanta hu"
  - "Ye cipher suites support karta hu: AES-256, ChaCha20..."
  - "Mera random number: xA3f..."
```

> **Cipher suite** = "Konsa taala-chaabi system use karein"

---

### Step 2 — ServerHello + Certificate: "Bank manager aata hai ID card lekar"

```
Server bolta hai:
  - "Hum AES-256 use karenge"
  - "Mera random number: k9Bx..."
  - "Ye le mera Certificate:
       Issuer: DigiCert (trusted CA)
       Valid: 2024-2026
       Domain: google.com
       Public Key: [long key...]"
```

> **Certificate = Server ki ID card**

---

### Step 3 — Client Verifies Certificate: "Tu ID card check karta hai"

Browser check karta hai:

1. Certificate kisi trusted CA ne issue kiya? (DigiCert, Let's Encrypt...)
2. Domain match karta hai? (google.com ka cert google.com ke liye?)
3. Expiry date valid hai?
4. Revoke toh nahi hua?

```
Sab theek  → Aage badho ✅
Kuch galat → RED WARNING — "SSL Certificate Error" ❌
```

---

### Step 4 — Key Exchange: "Secret code banane ki game"

**Paint mixing analogy:**

```
Sab ko pata hai    →  Common color = YELLOW

Tu choose karta hai   →  BLUE   (secret, kisi ko nahi bataya)
Server choose karta   →  RED    (secret, kisi ko nahi bataya)

Tu bhejta hai     →  Yellow + Blue  = GREEN   (public mein)
Server bhejta hai →  Yellow + Red   = ORANGE  (public mein)

Ab:
Tu leta hai       →  Orange + apna Blue  = BROWN 🟤
Server leta hai   →  Green  + apna Red   = BROWN 🟤

DONO KE PAAS SAME COLOR = BROWN
Kisi ko nahi pata BROWN kaise bana!
```

> **BROWN = Session Key** — ab isi se saari encryption hogi.  
> Computer mein ye **Diffie-Hellman / ECDH algorithm** karta hai.

---

### Step 5 — Encrypted Communication

```
Pehle  →  "Mera password hai: abc123"  (koi bhi sun sakta tha)
Ab     →  "xK92#mP@!qL..."             (sirf tum dono samajh sakte ho)
```

---

### Full Flow Summary

```
Tu (Browser)                    Server
     |                               |
     |--- ClientHello -------------->|
     |    (TLS version + ciphers)    |
     |                               |
     |<-- ServerHello + Certificate -|
     |                               |
     |--- Certificate verify ✅      |
     |    Key exchange (ECDH) ------>|
     |                               |
     |<-- Server key part -----------|
     |                               |
  DONO ke paas same Session Key 🔑   |
     |                               |
     |<====== ENCRYPTED DATA =======>|
```

### Step-by-step Table

| Step | Real Life | Computer |
|------|-----------|----------|
| ClientHello | "Kaunsi language?" | TLS version + cipher suites |
| ServerHello + Cert | Manager + ID card | TLS choice + Certificate |
| Verify | ID genuine hai? | CA chain check |
| Key Exchange | Paint mixing trick | ECDH algorithm |
| Session Key | Secret code ready | AES symmetric key |
| Encrypted comm | Secret room mein baat | Encrypted data |

### Interview Answer

> "TLS handshake mein client pehle supported versions aur ciphers bhejta hai. Server apna certificate bhejta hai jo client CA chain se verify karta hai. Phir Diffie-Hellman ke through dono same session key derive karte hain bina direct share kiye. Iske baad symmetric encryption se fast secure communication hoti hai."

---

## 4. CIDR — Subnetting

### Problem — CIDR kyun chahiye?

Billions of devices, har ek ka unique IP. Bina grouping ke routers ko poori duniya ki IPs ki list maintain karni padti — impossible!

**Solution = CIDR — IPs ko groups mein organize karo, jaise buildings mein flats.**

---

### Apartment Building Analogy

```
Society: "Nehru Nagar" (Network: 192.168.1.0)

Building A: Flat   1 – 100   →  192.168.1.1  – 192.168.1.100
Building B: Flat 101 – 200   →  192.168.1.101 – 192.168.1.200
Building C: Flat 201 – 300   →  192.168.1.201 – 192.168.1.254

Postman (Router): sirf "Nehru Nagar, Building B" pata hona chahiye
                  → wahan se exact flat dhundhta hai
```

---

### CIDR Notation

```
192.168.1.0/24
```

IP andar se 32 bits hai:
```
192   .  168  .   1  .   0
  ↓        ↓      ↓      ↓
11000000.10101000.00000001.00000000

/24 matlab:
|←——————— 24 bits FIXED ———————→|←— 8 bits FREE —→|
         NETWORK PART                  HOST PART
      (Building ka naam)            (Flat numbers)
```

**8 bits free = 2⁸ = 256 addresses → 254 usable**

---

### Formula

```
Total IPs  = 2^(32 - prefix)
Usable IPs = Total - 2
```

| CIDR | Total IPs | Usable |
|------|-----------|--------|
| /32 | 1 | 1 (single device) |
| /30 | 4 | 2 (point-to-point) |
| /28 | 16 | 14 |
| /26 | 64 | 62 |
| /24 | 256 | **254** ★ most common |
| /23 | 512 | 510 |
| /20 | 4,096 | 4,094 |
| /16 | 65,536 | **65,534** ★ AWS VPC default |
| /8 | 16,777,216 | 16M+ |

---

### 2 Reserved IPs — Why?

```
192.168.1.0    →  Network Address   ("Building ka naam" — device nahi milta)
192.168.1.255  →  Broadcast Address ("Poori building ko ek saath message")

192.168.1.1 – 192.168.1.254  →  254 usable devices ✅
```

---

### AWS VPC — Practical Example

```
VPC:  10.0.0.0/16  →  65,536 IPs  (poori society)

├── Public Subnet A:   10.0.1.0/24  (256 IPs)  — ALB, Bastion
├── Public Subnet B:   10.0.2.0/24  (256 IPs)  — ALB
├── Private Subnet A:  10.0.3.0/24  (256 IPs)  — EKS nodes, RDS
└── Private Subnet B:  10.0.4.0/24  (256 IPs)  — EKS nodes, RDS

Router ka kaam:
  Packet aaya for 10.0.3.45
  Router → "10.0.3.x? Ye Private Subnet A mein hai!" → direct bhej diya ✅
```

---

### 3 Reasons to Calculate CIDR

1. **Planning:** "Mere 500 servers hain → /23 chahiye (510 usable)"
2. **Security:** "Sirf 10.0.3.0/24 se traffic allow karo" — Building C only
3. **No waste:** 10 devices ke liye /16 liya → 65,526 IPs waste. /28 kaafi tha.

---

### Interview Questions

**Q: /24 mein kitne usable hosts?**
```
2^(32-24) = 2^8 = 256 → 256 - 2 = 254 ✅
```

**Q: 500 devices chahiye — kaunsa CIDR?**
```
/24 = 254  ❌ (kam pad jaayenge)
/23 = 2^9 = 512 → 510 usable ✅
```

**Q: 10.0.0.0/20 ka last IP?**
```
/20 = 2^12 = 4096 IPs
Start: 10.0.0.0
End:   10.0.15.255 ✅
```

---

### 1-Line Memory Trick

> "Slash ke baad number = kitne bits LOCK hain. Baaki bits FREE hain devices ke liye. 2^(free bits) = total IPs."

### 5 Numbers to Remember

| CIDR | Devices | Think of it as |
|------|---------|----------------|
| /32 | 1 | Single flat |
| /28 | 14 | Chhoti gali |
| /24 | 254 ★ | Ek building — most common |
| /16 | 65,534 ★ | Ek VPC — AWS default |
| /8 | 16M | Poora sheher |
