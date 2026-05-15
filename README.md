# DevOps Interview Prep — Sameer Khan

> 5 yrs · CKA · AZ-204 · EKS + OpenTofu + GitOps

---

## Where are you right now?

| I need to... | Go here |
|---|---|
| Interview in < 1 hour | [00-interview-day/15-min-refresh.md](00-interview-day/15-min-refresh.md) |
| Review a topic (30-60 min) | [01-cheatsheets/](01-cheatsheets/) |
| Do a hands-on lab session | [02-labs/](02-labs/) |
| Start or stop the EKS cluster | [02-labs/cluster-lifecycle.md](02-labs/cluster-lifecycle.md) |
| Study a topic deeply (2-3 hrs) | [03-deep-dive/](03-deep-dive/) |
| Find a real production bug I debugged | [04-gotchas/eks-incidents.md](04-gotchas/eks-incidents.md) |
| Prep for project architecture questions | [00-interview-day/project-guide.md](00-interview-day/project-guide.md) |
| Prep for company-specific STAR questions | [00-interview-day/resume-guide.md](00-interview-day/resume-guide.md) |

---

## 00 — Interview Day

> Open this folder the morning of the interview. Read in this order.

| File | What's in it | When |
|---|---|---|
| [15-min-refresh.md](00-interview-day/15-min-refresh.md) | K8s · AWS · IaC · Observability rapid fire + 5 mindset rules | 30 min before |
| [star-stories.md](00-interview-day/star-stories.md) | 6 STAR stories — memorize the arc, not word-for-word | Night before |
| [questions-to-ask.md](00-interview-day/questions-to-ask.md) | 10 smart questions for the interviewer | Last 5 min |
| [project-guide.md](00-interview-day/project-guide.md) | EKS lab — architecture diagram, 15 pre-loaded Q&A, numbers to quote | Deep project prep |
| [resume-guide.md](00-interview-day/resume-guide.md) | All 3 companies — context blocks, STAR stories, tech explainers, trap questions | Company prep |

---

## 01 — Cheatsheets

> Quick review. One file per session. Don't read all at once.

| File | Covers |
|---|---|
| [linux-networking.md](01-cheatsheets/linux-networking.md) | Linux · Networking · AWS · IAM · HA/DR · Well-Architected |
| [kubernetes.md](01-cheatsheets/kubernetes.md) | EKS · Pod lifecycle · Networking · Storage · Helm · Autoscaling |
| [platform.md](01-cheatsheets/platform.md) | Secrets · GitOps · OpenTofu · CI/CD · cert-manager · Observability |
| [interview-qa.md](01-cheatsheets/interview-qa.md) | Q&A rapid fire · Hindi analogies |
| [kubectl-commands.md](01-cheatsheets/kubectl-commands.md) | kubectl reference — troubleshooting, rollouts, RBAC, node ops |

---

## 02 — Labs

> Hands-on sessions. Cluster costs $5-8/hr — start it, do the session, destroy same day.

| File | What you'll do |
|---|---|
| [cluster-lifecycle.md](02-labs/cluster-lifecycle.md) | Start/stop cluster · full runbook · destroy order · port forwards |
| [runbook-iac.md](02-labs/runbook-iac.md) | OpenTofu create/destroy · prerequisites · DependencyViolation fix |
| [runbook-cicd.md](02-labs/runbook-cicd.md) | GitHub Actions setup · secrets/variables · recreate after destroy |
| [hands-on-remaining.md](02-labs/hands-on-remaining.md) | Prioritized task list — Tier 1 (core) → Tier 2 → Tier 3 |
| [session-a-monitoring.md](02-labs/session-a-monitoring.md) | kube-prometheus-stack · PromQL · RED dashboard · Alloy · Loki · ServiceMonitor |
| [session-b-autoscaling.md](02-labs/session-b-autoscaling.md) | HPA · KEDA · PDB · VPA |
| [session-c-gitops.md](02-labs/session-c-gitops.md) | ArgoCD · External Secrets Operator |
| [session-d-policies.md](02-labs/session-d-policies.md) | NetworkPolicy · ResourceQuota · LimitRange |

---

## 03 — Deep Dive

> Study a topic from first principles. 2-3 hour sessions. Your original study notes.

| Folder | What's inside |
|---|---|
| [foundation/](03-deep-dive/foundation/) | Day 1-3: Linux, Networking, STAR stories setup |
| [cloud-core/](03-deep-dive/cloud-core/) | Day 4-7: AWS Networking, IAM, Compute, EKS, Azure, GCP |
| [kubernetes/](03-deep-dive/kubernetes/) | Day 8-10: K8s internals, Networking, Storage, Helm |
| [iac-cicd/](03-deep-dive/iac-cicd/) | Day 11-12: OpenTofu, GitHub Actions, Azure DevOps |
| [observability/](03-deep-dive/observability/) | Day 13: Prometheus, Grafana, OTel, Logging |
| [mock-sessions/](03-deep-dive/mock-sessions/) | Day 14-15: System design mock, final mock + stories |

---

## 04 — Gotchas

> Real production incidents you personally debugged. Your strongest interview answers.

| File | What's in it |
|---|---|
| [eks-incidents.md](04-gotchas/eks-incidents.md) | 5 real debug logs + 10 production gotcha patterns |
| [top-50-qa.md](04-gotchas/top-50-qa.md) | Top 50 interview Q&A — K8s, AWS, IaC, Observability, Behavioral |
| [system-design.md](04-gotchas/system-design.md) | 5 system design templates + universal 15-min framework |

---

## Infrastructure + App (not study material)

| | |
|---|---|
| [iac/](iac/) | OpenTofu modules — VPC, EKS |
| [app/](app/) | s3-lister Helm chart + app code |
| [.github/workflows/](.github/workflows/) | CI/CD: infra-apply · bootstrap · ci · destroy |
| [00-guide/](00-guide/) | Original PDF prep guide + resume PDF |

---

*"Tu rusty hai, weak nahi. Rust 15 din mein hat jaati hai."*
