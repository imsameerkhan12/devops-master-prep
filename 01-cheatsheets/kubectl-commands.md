# kubectl Command Cheatsheet

## Troubleshooting Flow
```bash
kubectl get pods -A                                        # overview all namespaces
kubectl get pods -n <ns> -o wide                           # with node + IP
kubectl describe pod <pod> -n <ns>                         # events + full spec
kubectl logs <pod> -n <ns> -c <container>                  # container logs
kubectl logs <pod> --previous                              # previous container (after restart)
kubectl exec -it <pod> -- /bin/sh                          # shell inside container
kubectl debug -it <pod> --image=busybox --target=<c>       # debug distroless
kubectl get events --sort-by='.lastTimestamp' -n <ns>      # timeline of events
```

## Resource Management
```bash
kubectl top pods -n <ns>                                   # CPU + memory usage
kubectl top nodes                                          # node resource usage
kubectl describe node <node>                               # node capacity + allocated
kubectl get hpa -n <ns>                                    # horizontal pod autoscalers
```

## Deployments
```bash
kubectl rollout status deployment/<name> -n <ns>           # watch rollout
kubectl rollout history deployment/<name>                  # revision history
kubectl rollout undo deployment/<name>                     # rollback to previous
kubectl rollout undo deployment/<name> --to-revision=3     # rollback to specific

kubectl set image deployment/<name> app=image:tag          # quick image update
kubectl scale deployment/<name> --replicas=5               # scale
```

## RBAC Testing
```bash
kubectl auth can-i get pods --as=user@example.com
kubectl auth can-i create deployments --as=system:serviceaccount:default:my-sa -n production
kubectl auth whoami
```

## Node Operations
```bash
kubectl cordon <node>                                      # mark unschedulable
kubectl uncordon <node>                                    # mark schedulable
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data   # evict pods
```

## Useful Queries
```bash
# All pods not running
kubectl get pods -A --field-selector=status.phase!=Running

# Events for failed pods
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp'

# Resource usage by namespace
kubectl top pods -A --sort-by=memory

# Get all images in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Which node is each pod on
kubectl get pods -o wide -A | grep -v Completed
```

## Port Forwarding + Proxy
```bash
kubectl port-forward svc/<svc> 8080:80 -n <ns>            # forward service port locally
kubectl port-forward pod/<pod> 8080:8080                   # forward pod port
kubectl proxy                                              # API server proxy on localhost:8001
```
