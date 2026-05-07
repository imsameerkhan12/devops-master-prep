# Phase 1: Foundation (Day 1–3)

**Goal:** Remove Linux/networking rust. Build STAR story bank for behavioral rounds.

Behavioral round ka 80% yahan se cover hoga.

---

## Days

| Day | Topic | Key Deliverable |
|-----|-------|----------------|
| [Day 1](day-01-setup-and-star-stories/) | Setup + STAR Stories | 6 project STAR stories (200 words each) |
| [Day 2](day-02-linux-fundamentals/) | Linux Fundamentals | 20-command personal cheatsheet |
| [Day 3](day-03-networking-deep/) | Networking Deep | 5 core Q&A answers ready |

---

## Core Concepts This Phase

### STAR Format
- **S**ituation → **T**ask → **A**ction → **R**esult
- Numbers mandatory in Result: "50 services migrated", "$X/month saved"
- Each story: 2 minutes max

### Linux Must-Know
- `chmod/chown/umask` — numeric + symbolic
- `SIGTERM` (graceful, app cleans up) vs `SIGKILL` (immediate, no cleanup)
- K8s sends SIGTERM first → grace period → SIGKILL
- `ss -tunlp`, `lsof -i :8080`, `dig +trace`, `curl -v`, `tcpdump`
- `set -euo pipefail` — production script standard

### Networking Must-Know
- OSI: L3=IP (VPC/subnets), L4=TCP/UDP (NLB, SG ports), L7=HTTP (ALB, Ingress, WAF)
- TCP: SYN → SYN-ACK → ACK (3-way handshake)
- DNS: A, AAAA, CNAME, MX, TXT, NS | TTL = cache duration
- `/24` = 254 usable IPs | Formula: `2^(32-prefix) - 2`
- L4 LB = fast, no content inspection | L7 LB = HTTP-aware, path routing, WAF
- HTTP: 2xx success, 3xx redirect, 4xx client (401/403/404/429), 5xx server (500/502/503/504)
