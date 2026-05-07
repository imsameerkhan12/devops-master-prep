# Day 10: Helm + Troubleshooting + Production Patterns

## Helm Chart Anatomy

```
mychart/
├── Chart.yaml          # metadata: name, version, appVersion, dependencies
├── values.yaml         # default config (user overrides with -f or --set)
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # reusable named templates
│   └── NOTES.txt       # shown after install
└── charts/             # sub-chart dependencies
```

### Key Templating Patterns
```yaml
# Default value
image:
  tag: {{ .Values.image.tag | default "latest" | quote }}

# Conditional
{{- if .Values.ingress.enabled }}
# ingress resource here
{{- end }}

# Loop
{{- range .Values.extraEnvVars }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}

# Named template (defined in _helpers.tpl)
{{- define "myapp.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end }}

# Use it:
name: {{ include "myapp.fullname" . }}
```

**`{{-` vs `{{`:** Dash trims whitespace. Always use `{{-` to avoid blank lines.

---

## Helm Lifecycle + Hooks

```
helm install → helm upgrade → helm rollback → helm uninstall
```

### Hooks
```yaml
annotations:
  "helm.sh/hook": pre-upgrade          # runs before upgrade
  "helm.sh/hook-weight": "-5"          # lower = runs first
  "helm.sh/hook-delete-policy": before-hook-creation
```

**Use case:** DB migration Job as `pre-upgrade` hook → runs migration before app is updated.

```bash
helm history myapp                     # see all revisions
helm rollback myapp 3                  # rollback to revision 3
helm get values myapp --revision 3     # see values at revision 3
```

---

## Pulumi vs Helm

| | Helm | Pulumi |
|-|------|--------|
| Language | Go templates (YAML) | TypeScript, Python, Go |
| Logic | Limited (if/range) | Full programming (loops, classes, conditions) |
| Type safety | None | Full IDE support |
| Tests | None | Unit tests for infra |
| Best for | App deployments, distributing charts | Complex infra, multi-cloud, conditional logic |

**Your articulation:** "TokenTide pe Pulumi — Dgraph deployment mein conditional logic + custom resources needed. Cybage pe Terraform — team was familiar, simpler infra."

---

## K8s Troubleshooting Framework

```bash
# Step 1: Overview
kubectl get pods -A

# Step 2: Events (MOST USEFUL)
kubectl describe pod <name> -n <namespace>
# Look at: Events section at bottom

# Step 3: App logs
kubectl logs <pod> -c <container>
kubectl logs <pod> --previous    # previous container instance (after CrashLoop)

# Step 4: Live debug inside container
kubectl exec -it <pod> -- /bin/sh
# or for distroless images:
kubectl debug -it <pod> --image=busybox --target=<container>

# Step 5: Cluster events timeline
kubectl get events --sort-by='.lastTimestamp' -n <namespace>
```

---

## K8s Troubleshooting Cheatsheet — Top 10 Errors

| Error | Immediate Check | Fix |
|-------|----------------|-----|
| `ImagePullBackOff` | `kubectl describe pod` → Events | Fix image name, add imagePullSecret |
| `CrashLoopBackOff` | `kubectl logs --previous` | Fix app crash, check envvars/config |
| `OOMKilled` | `kubectl describe pod` → Last State | Increase memory limit |
| `Pending` | `kubectl describe pod` → Events | Check node resources, taints, PVC |
| `Evicted` | `kubectl get events` | Increase node disk/memory |
| `CreateContainerConfigError` | `kubectl describe pod` | Missing ConfigMap or Secret |
| `RunContainerError` | `kubectl describe pod` | Bad entrypoint, missing binary |
| PVC Pending | `kubectl describe pvc` | StorageClass missing, provisioner error |
| Service not routing | `kubectl get endpoints` | Selector mismatch, port mismatch |
| Node NotReady | `kubectl describe node` | kubelet issue, disk pressure |

---

## Deployment Strategies

### Rolling Update (Default)
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # max extra pods above desired
    maxUnavailable: 0    # zero downtime — never take pods down before new ones up
```

### Blue-Green
- Two full environments (blue = current, green = new)
- Switch traffic at LB/Ingress level → instant cutover
- Fast rollback: switch back
- Double cost during transition

### Canary (Argo Rollouts)
```yaml
# 5% traffic → new version, monitor, gradually 100%
# Argo Rollouts automates this with:
# - Prometheus metrics gates
# - Manual promotion or auto-promotion
```

### Feature Flags
- Code deployed but feature hidden behind flag (LaunchDarkly, Unleash)
- Separates deploy from release → safer

---

## Hands-on Checklist
- [ ] Custom Helm chart from scratch: webapp + service + ingress
- [ ] Intentional break: wrong image, OOM trigger → debug with `kubectl describe`
- [ ] Helm conditional logic: dev vs prod values
- [ ] `helm rollback` across 3 revisions
