# IaC Tool — OpenTofu Not Terraform
Always use OpenTofu (not Terraform). HashiCorp changed to BSL license Aug 2023 — no longer open source. OpenTofu is the Linux Foundation fork under MPL 2.0.
- Commands: `tofu init`, `tofu plan`, `tofu apply`, `tofu destroy`
- Install: `choco install opentofu`
- HCL syntax identical — all .tf files work as-is
- Interview answer: "We use OpenTofu — drop-in replacement after Terraform's BSL license change"

# Always Teach Latest — Never Legacy
Sameer interviews for Senior DevOps roles in 2026. Always give current practice first, flag legacy explicitly.
- State locking → `use_lockfile = true` (S3 native, Terraform 1.10+) — NOT DynamoDB
- EKS auth → Access Entries API — NOT aws-auth ConfigMap
- Ingress → Traefik + Gateway API — NOT Nginx (retired March 2026)
- Secrets → External Secrets Operator — NOT manual kubectl secrets
- Node autoscaling → Karpenter — NOT Cluster Autoscaler
- If updated in last 18 months → say "old way was X, new way is Y"
