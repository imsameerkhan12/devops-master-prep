# Session C — GitOps + Secrets
> ArgoCD · External Secrets Operator

---

## Task 8: ArgoCD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace \
  --set configs.params.server.insecure=true

kubectl port-forward -n argocd svc/argocd-server 8080:80

# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

### Application CR — s3-lister via GitOps

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: s3-lister
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/imsameerkhan12/devops-master-prep
    targetRevision: main
    path: app/s3-lister/chart
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true       # delete K8s resources removed from Git
      selfHeal: true    # revert manual kubectl apply changes
```

```bash
kubectl apply -f argocd-app.yaml
# Watch sync: kubectl get application -n argocd -w
```

> **Note:** ArgoCD needs ~600MB RAM — too heavy for t3.medium with everything else running.  
> Alternative: Flux CD (lighter, CNCF graduated).

---

## Task 9: External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace
```

### ClusterSecretStore + ExternalSecret

```yaml
# Step 1 — ClusterSecretStore (where to get secrets)
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

---
# Step 2 — ExternalSecret (what to sync)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dockerhub-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: dockerhub-creds
  data:
  - secretKey: .dockerconfigjson
    remoteRef:
      key: prod/dockerhub/credentials
```

```bash
kubectl apply -f clusterSecretStore.yaml
kubectl apply -f externalSecret.yaml

# Verify
kubectl get externalsecret -n default
kubectl get secret dockerhub-creds -n default
```

---

## ArgoCD vs Flux

| | ArgoCD | Flux |
|-|--------|------|
| Market share | ~60% | ~40% |
| UI | Rich web UI | CLI-first |
| Memory | ~600MB+ | Lighter |
| Use when | Need a UI + multi-cluster | Lightweight, CNCF purist |
