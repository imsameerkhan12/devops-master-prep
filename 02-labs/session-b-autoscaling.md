# Session B — Autoscaling
> HPA · KEDA · PDB · VPA

---

## Task 6: HPA for s3-lister

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: s3-lister-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: s3-lister
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

```bash
kubectl apply -f hpa.yaml

# Load test
kubectl run load --image=busybox --restart=Never -- /bin/sh -c \
  "while true; do wget -q -O- http://s3-lister.default.svc.cluster.local; done"

kubectl get hpa -n default -w
```

---

## Task 7: KEDA + ScaledObject

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace keda --create-namespace
```

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: s3-lister-scaler
spec:
  scaleTargetRef:
    name: s3-lister
  minReplicaCount: 0
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring:9090
      metricName: http_requests_total
      threshold: "100"
      query: sum(rate(http_requests_total[2m]))
```

> **Rule:** Do NOT use HPA + KEDA ScaledObject on same Deployment — they compete.

---

## Task 10: PDB

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: s3-lister-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels: {app: s3-lister}
```

```bash
# Test: drain a node and watch PDB protect the pod
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl get pods -w   # only 1 pod evicted at a time
kubectl uncordon <node-name>
```

---

## Task 11 (bonus): VPA in Off mode

```bash
# Install VPA (if not installed)
kubectl apply -f https://github.com/kubernetes/autoscaler/raw/master/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml
```

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: s3-lister-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: s3-lister
  updatePolicy:
    updateMode: "Off"   # Recommendations only, no automatic changes
```

```bash
kubectl apply -f vpa.yaml
kubectl describe vpa s3-lister-vpa   # read recommendations
```

---

## Autoscaling Decision Table

| Tool | Scales | When to use |
|------|--------|------------|
| HPA | Pods (out/in) | REST APIs on CPU/memory |
| KEDA | Pods (+ to zero) | Background workers, queues, events |
| VPA | Pod CPU/memory requests | Right-sizing, cost optimization |
| Karpenter | Nodes | Add/remove EC2 nodes on EKS |
