# Day 8: K8s Core + Pod Lifecycle

## Pod Lifecycle Phases

| Phase | Meaning | Common Cause |
|-------|---------|-------------|
| Pending | Not scheduled yet | No resources, PVC not bound, taint |
| Running | At least 1 container running | — |
| Succeeded | All containers exited 0 | Jobs |
| Failed | At least 1 container exited non-zero | App crash |
| Unknown | kubelet unreachable | Node problem |

### Common Error States
| Error | Root Cause |
|-------|-----------|
| `ImagePullBackOff` | Wrong image name, registry auth, network |
| `CrashLoopBackOff` | App crashes on start → check `kubectl logs --previous` |
| `OOMKilled` | Memory limit too low |
| `Evicted` | Node pressure (disk/memory) |
| `Pending` | No nodes with resources, taint without toleration, PVC not bound |

---

## Probes — CRITICAL INTERVIEW TOPIC

### Liveness Probe
- Question asked: "Is the app alive?"
- **Fail action:** kubelet **RESTARTS** the container
- Risk: Aggressive liveness → endless restart loop on slow startup

### Readiness Probe
- Question asked: "Can the app serve traffic?"
- **Fail action:** Service **removes** pod from endpoints (no restarts)
- Safe to be aggressive

### Startup Probe
- For slow-starting apps (JVM warmup, etc.)
- Liveness + Readiness are **disabled** until startup probe passes

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
  failureThreshold: 2

startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30   # 30 × 10s = 5 min max startup time
  periodSeconds: 10
```

**Interview gotcha — if you swap liveness and readiness:**
- Aggressive liveness = pod keeps restarting on any slow response
- No readiness = traffic sent to pods that aren't ready yet → errors

---

## Resource Requests vs Limits

```yaml
resources:
  requests:
    cpu: "250m"      # scheduler sees this — guaranteed allocation
    memory: "256Mi"
  limits:
    cpu: "500m"      # CPU: throttled when exceeded (not killed)
    memory: "512Mi"  # Memory: OOMKilled when exceeded
```

### QoS Classes (Eviction Order)

| Class | Condition | Evicted |
|-------|-----------|---------|
| Guaranteed | requests == limits for CPU + memory | Last |
| Burstable | requests < limits | Middle |
| BestEffort | No requests or limits | **First** |

---

## Scheduling Controls

```yaml
# nodeSelector — simple
nodeSelector:
  kubernetes.io/arch: amd64

# Node Affinity — preferred (soft) or required (hard)
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values: ["gpu"]

# Pod Anti-Affinity — spread replicas across nodes
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: myapp
        topologyKey: kubernetes.io/hostname

# Taints + Tolerations
# Node: kubectl taint nodes gpu-node gpu=true:NoSchedule
# Pod:
tolerations:
- key: "gpu"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

---

## StatefulSet vs Deployment

| | Deployment | StatefulSet |
|-|------------|-------------|
| Pod identity | Random names (pod-xyz) | Stable names (pod-0, pod-1) |
| Storage | Shared or ephemeral | Each pod gets own PVC |
| Start order | Parallel | **Sequential** (0, 1, 2...) |
| Delete order | Any | **Reverse** (2, 1, 0...) |
| DNS | Single service | `pod-0.svc`, `pod-1.svc` (headless) |
| Use case | Stateless | DBs, queues, Kafka, Zookeeper |

---

## End-of-Day Q&A

**Q1: Swap liveness ↔ readiness — what happens?**  
App slow → readiness-as-liveness = pod killed (OOMKill loop). Liveness-as-readiness = traffic goes to not-ready pods → errors.

**Q2: StatefulSet vs Deployment — 4 differences?**  
1. Stable pod name (pod-0) vs random. 2. Per-pod PVC vs shared. 3. Ordered start/stop vs parallel. 4. Headless DNS per pod vs single service.

**Q3: Pod Pending — 5 debug steps?**  
1. `kubectl describe pod` → Events. 2. Insufficient resources → check nodes `kubectl describe node`. 3. Taint without toleration. 4. PVC not bound → `kubectl get pvc`. 5. Image pull issue (might be Pending then ImagePullBackOff).
