# DevOps Master Prep — Sameer Khan

**15-day structured interview prep** | Senior DevOps / Cloud Engineer  
**Daily:** 10:00 AM – 1:00 PM (3 hours) | **Total:** 45 hours  
**Goal:** Interview-ready across AWS, K8s, OpenTofu, CI/CD, Observability, System Design

---

## Roadmap at a Glance

| Phase | Days | Focus | Outcome |
|-------|------|-------|---------|
| [Phase 1: Foundation](phase-1-foundation/) | 1–3 | Linux, Networking, STAR Stories | Behavioral confidence |
| [Phase 2: Cloud Core](phase-2-cloud-core/) | 4–7 | AWS deep, Azure refresh, GCP touch | Cloud rust removed |
| [Phase 3: Kubernetes](phase-3-kubernetes/) | 8–10 | K8s deep, Helm, troubleshooting | K8s production-ready |
| [Phase 4: IaC + CI/CD](phase-4-iac-cicd/) | 11–12 | OpenTofu, Pulumi, GitHub Actions | Pipeline fluency |
| [Phase 5: Observability](phase-5-observability/) | 13 | Prometheus, Grafana, OTel, Logging | Triage skills |
| [Phase 6: Polish](phase-6-mock-polish/) | 14–15 | Mock interviews, system design | Interview-ready |

---

## Daily Routine (3 hours)

| Time | Activity | Why |
|------|----------|-----|
| 10:00 – 10:15 | Previous day quick recap | Memory consolidation |
| 10:15 – 11:30 | New topic — video + docs | Core learning (75 min) |
| 11:30 – 11:45 | Break (chai, walk) | Brain reset |
| 11:45 – 12:45 | Hands-on lab / practice | Implementation muscle |
| 12:45 – 1:00 | Write notes in own words | Retention boost |

---

## Repo Structure

```
DEVOPS-REMASTER/
├── 00-guide/                          # The original PDF prep guide
├── phase-1-foundation/
│   ├── day-01-setup-and-star-stories/
│   ├── day-02-linux-fundamentals/
│   └── day-03-networking-deep/
├── phase-2-cloud-core/
│   ├── day-04-aws-networking-iam/
│   ├── day-05-aws-compute-storage-eks/
│   ├── day-06-aws-specialized-azure/
│   └── day-07-aws-practical-gcp/
├── phase-3-kubernetes/
│   ├── day-08-k8s-core-pod-lifecycle/
│   ├── day-09-k8s-networking-storage-security/
│   └── day-10-helm-troubleshooting-patterns/
├── phase-4-iac-cicd/
│   ├── day-11-terraform-pulumi/
│   └── day-12-github-actions-azure-devops/
├── phase-5-observability/
│   └── day-13-prometheus-grafana-otel-logging/
├── phase-6-mock-polish/
│   ├── day-14-system-design-mock/
│   └── day-15-final-mock-stories/
├── reference/
│   ├── interview-questions/           # Top 50 Q&A answers
│   ├── system-design-templates/       # Design frameworks + templates
│   ├── behavioral-stories/            # 6 STAR stories
│   └── cheatsheets/                   # Quick-lookup references
└── scripts/                           # Shell scripts for hands-on practice
```

Each day folder has:
- `notes/` — your notes written in own words after study
- `hands-on/` — scripts, YAMLs, configs from lab practice

---

## Golden Rules

- **Active > Passive:** After every video/doc, write it in your own words. Can't write = didn't understand.
- **Hands-on mandatory:** Deploy something every single day.
- **Resume-first:** For every topic, connect it to a project on your resume.
- **80% of 100 > 100% of 20:** Move on. Don't chase perfection.
- **Sleep 7+:** Memory consolidates during sleep. Non-negotiable.

---

## Practice Notes — Day Wise

> Har din ke notes yahan se directly open karo. Practice file = hands-on log + concepts apne shabdon mein.

| Day | Topic | Notes (Theory) | Practice (Hands-on) | Status |
|-----|-------|---------------|---------------------|--------|
| Day 1 | Setup + STAR Stories | [README](phase-1-foundation/day-01-setup-and-star-stories/notes/README.md) | — | ✅ |
| Day 2 | Linux Fundamentals | [README](phase-1-foundation/day-02-linux-fundamentals/notes/README.md) | [practice.md](phase-1-foundation/day-02-linux-fundamentals/notes/practice.md) | ✅ |
| Day 3 | Networking Deep | [README](phase-1-foundation/day-03-networking-deep/notes/README.md) | [practice.md](phase-1-foundation/day-03-networking-deep/notes/practice.md) | ✅ |
| Day 4 | AWS Networking + IAM | [README](phase-2-cloud-core/day-04-aws-networking-iam/notes/README.md) | [practice.md](phase-2-cloud-core/day-04-aws-networking-iam/notes/practice.md) | ✅ |
| Day 5 | AWS Compute + EKS | [README](phase-2-cloud-core/day-05-aws-compute-storage-eks/notes/README.md) | [practice.md](phase-2-cloud-core/day-05-aws-compute-storage-eks/notes/practice.md) | ✅ |
| Day 6 | AWS Specialized + Azure | [README](phase-2-cloud-core/day-06-aws-specialized-azure/notes/README.md) | — | ⏳ |
| Day 7 | AWS Practical + GCP | [README](phase-2-cloud-core/day-07-aws-practical-gcp/notes/README.md) | — | ⏳ |
| Day 8 | K8s Core + Pod Lifecycle | [README](phase-3-kubernetes/day-08-k8s-core-pod-lifecycle/notes/README.md) | — | ⏳ |
| Day 9 | K8s Networking + Storage | [README](phase-3-kubernetes/day-09-k8s-networking-storage-security/notes/README.md) | — | ⏳ |
| Day 10 | Helm + Troubleshooting | [README](phase-3-kubernetes/day-10-helm-troubleshooting-patterns/notes/README.md) | — | ⏳ |
| Day 11 | OpenTofu + Pulumi | [README](phase-4-iac-cicd/day-11-terraform-pulumi/notes/README.md) | [practice.md](phase-4-iac-cicd/day-11-terraform-pulumi/notes/practice.md) · [RUNBOOK](phase-4-iac-cicd/day-11-terraform-pulumi/notes/RUNBOOK.md) | ✅ |
| Day 12 | GitHub Actions + Azure DevOps | [README](phase-4-iac-cicd/day-12-github-actions-azure-devops/notes/README.md) | [practice.md](phase-4-iac-cicd/day-12-github-actions-azure-devops/notes/practice.md) | ⏳ |
| Day 13 | Prometheus + Grafana + OTel | [README](phase-5-observability/day-13-prometheus-grafana-otel-logging/notes/README.md) | — | ⏳ |
| Day 14 | System Design Mock | [README](phase-6-mock-polish/day-14-system-design-mock/notes/README.md) | — | ⏳ |
| Day 15 | Final Mock + Stories | [README](phase-6-mock-polish/day-15-final-mock-stories/notes/README.md) | — | ⏳ |

**Status:** ✅ Done · 🔄 In Progress · ⏳ Pending

---

## Reference Links

- [Top 50 Interview Questions](reference/interview-questions/top-50.md)
- [Day-of-Interview Cheatsheet](reference/cheatsheets/day-of-interview.md)
- [System Design Templates](reference/system-design-templates/)
- [STAR Behavioral Stories](reference/behavioral-stories/)
- [Original PDF Guide](00-guide/Sameer_DevOps_Master_Prep_Guide.pdf)

---

*Tu rusty hai, weak nahi. Rust 15 din mein hat jaati hai. Chal shuru kar.*
