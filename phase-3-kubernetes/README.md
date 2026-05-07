# Phase 3: Kubernetes Deep (Day 8–10)

**Goal:** CKA foundation strong. Shift to production scenarios + troubleshooting.

---

## Days

| Day | Topic | Key Deliverable |
|-----|-------|----------------|
| [Day 8](day-08-k8s-core-pod-lifecycle/) | K8s Core + Pod Lifecycle | Liveness vs Readiness, StatefulSet vs Deploy, Pending debug |
| [Day 9](day-09-k8s-networking-storage-security/) | Networking + Storage + Security | Internet→Pod full flow diagram |
| [Day 10](day-10-helm-troubleshooting-patterns/) | Helm + Troubleshooting + Patterns | Personal K8s troubleshooting cheatsheet |

---

## K8s Quick Reference

### Workload Decision Tree
| Use Case | Resource |
|----------|---------|
| Stateless app | Deployment |
| Stateful (DB, queue) | StatefulSet |
| Per-node agent (logging, monitoring) | DaemonSet |
| One-time task | Job |
| Scheduled task | CronJob |

### kubectl Troubleshooting Flow
```bash
kubectl get pods -A                              # Step 1: Overview
kubectl describe pod <name>                      # Step 2: Events (gold)
kubectl logs <name> [--previous]                 # Step 3: App errors
kubectl exec -it <name> -- /bin/sh               # Step 4: Inside investigate
kubectl get events --sort-by='.lastTimestamp'    # Step 5: Cluster events
```
