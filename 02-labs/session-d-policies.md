# Session D — Policies + Multi-tenancy
> NetworkPolicy · ResourceQuota · LimitRange

---

## Task 12: NetworkPolicy — Deny All Ingress

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes: [Ingress]
EOF
```

> `podSelector: {}` = selects ALL pods. No ingress rules = deny all traffic to the namespace.

### Allow only from traefik namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-traefik
  namespace: default
spec:
  podSelector:
    matchLabels: {app: s3-lister}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: traefik
    ports:
    - port: 80
```

```bash
# Test — curl from a pod in a different namespace (should fail)
kubectl run test-pod --image=busybox -n kube-system --restart=Never -- \
  /bin/sh -c "wget -qO- http://s3-lister.default.svc.cluster.local"
# Should hang/fail

# Test — curl from traefik namespace (should succeed)
kubectl exec -it -n traefik $(kubectl get pods -n traefik -o name | head -1) -- \
  wget -qO- http://s3-lister.default.svc.cluster.local
```

> **Requires CNI support:** Calico, Cilium. AWS VPC CNI does NOT support NetworkPolicy by default — needs a separate network policy controller.

---

## Task 13: ResourceQuota + LimitRange

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: default
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    pods: "20"
EOF
```

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: default
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
EOF
```

```bash
# Test — create a pod without requests (LimitRange should apply defaults)
kubectl run test-pod --image=nginx --restart=Never -n default
kubectl describe pod test-pod -n default | grep -A 5 "Limits:"

# Test — exceed quota (should fail)
kubectl run pod1 --image=nginx -n default
kubectl run pod2 --image=nginx -n default
# ... keep creating until quota exceeded
```

---

## What These Protect Against

| Resource | Problem it solves |
|----------|------------------|
| NetworkPolicy | Blast radius from a compromised pod — it can't reach other namespaces |
| ResourceQuota | One team starving others — limits total resources per namespace |
| LimitRange | Pod without requests gets BestEffort QoS — first evicted under pressure |
