# Day 6: AWS Specialized + Azure Refresh

## Parameter Store vs Secrets Manager

| | Parameter Store | Secrets Manager |
|-|----------------|----------------|
| Cost | Standard = FREE | $0.40/secret/month + $0.05/10k API calls |
| Rotation | Manual | **Auto-rotation built-in** |
| Types | String, StringList, SecureString (KMS) | JSON secrets |
| Best for | Config, static secrets, env vars | DB passwords, API keys needing rotation |

**Your resume:** "Compliance Innovation pe SSM Parameter Store use kiya — 50+ services, cost-effective, CloudTrail audit."  
**Decision rule:** RDS/Aurora password → Secrets Manager (rotation). Everything else → Parameter Store.

---

## External Secrets Operator (ESO) — YOUR KEY RESUME ITEM

### What
K8s controller that syncs secrets from external sources (SSM, Vault, GCP Secret Manager) into K8s Secrets automatically.

### Components
```
SecretStore    → Provider config (which AWS account, region, auth method)
ExternalSecret → What to sync (which SSM path → which K8s secret key)
ServiceAccount → IAM role via IRSA (how ESO talks to AWS)
```

### 4-Step Flow
```
1. ExternalSecret CRD created (declares: sync /myapp/db-password → k8s secret "db-creds")
2. ESO controller watches ExternalSecret, calls AWS SSM API via IRSA
3. Creates K8s Secret with synced value
4. Pod mounts K8s Secret as env var or volume
   (auto-refreshes per refreshInterval, default 1h)
```

### Why It's Better
- No secrets in Git
- No manual sync scripts
- Audit trail in AWS CloudTrail
- Auto-refresh when secret rotates

---

## CloudWatch Basics

### Logs
```
Log Group (e.g., /aws/eks/my-cluster/application)
  └── Log Stream (per pod/container)
        └── Log Events (individual lines)
```

### Logs Insights Query
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

### Metrics
- Namespaced: `AWS/EC2`, `AWS/EKS`, `ContainerInsights`
- Dimensions: instance-id, cluster-name, namespace
- Standard resolution: 1 min | High resolution: 1 sec (paid)

### Alarms → Actions
CloudWatch Alarm → SNS → PagerDuty / Slack  
CloudWatch Alarm → Auto Scaling policy  
CloudWatch Alarm → Lambda function

---

## RDS Multi-AZ vs Read Replica

| | Multi-AZ | Read Replica |
|-|----------|-------------|
| Replication | **Synchronous** | Asynchronous (lag possible) |
| Purpose | HA + automatic failover | Read scaling |
| Failover time | 60–120 seconds automatic | Manual promotion |
| Cross-region | No | **Yes** |

**Production pattern:** Multi-AZ primary + 2-3 Read Replicas  
**Failover:** DNS CNAME updated automatically by RDS — app reconnects to same endpoint

---

## Azure Refresh — AZ-204 Quick Hits

### AKS vs EKS
- AKS control plane = **FREE** (EKS = $73/month)
- Azure CNI vs Kubenet (Kubenet = basic, Azure CNI = pod gets VNet IP like VPC CNI)
- Azure AD RBAC integration = cleaner than EKS + IAM combo

### Key Azure Services
| AWS | Azure |
|-----|-------|
| EKS | AKS |
| ECR | ACR (Azure Container Registry) |
| Secrets Manager | Key Vault |
| IAM Role | Managed Identity |
| CloudWatch | Azure Monitor |
| CodePipeline | Azure DevOps Pipelines |

### Azure DevOps Pipelines (YOUR STRENGTH)
- Stages → Jobs → Steps
- **Service connections:** Cloud auth (AWS/Azure/GCP), Docker registry, GitHub
- **Variable groups:** Shared vars across pipelines, can link to Key Vault
- **Environments + Approvals:** Manual gate between stages (e.g., approve before prod)
- **Agent pools:** Microsoft-hosted (free tier), self-hosted, scale-set agents

### GitHub Actions vs Azure DevOps
| | GitHub Actions | Azure DevOps |
|-|---------------|--------------|
| Best for | Open source, GitHub-native, modern | Enterprise, existing ADO investment |
| Secrets | GitHub Secrets + OIDC | Variable Groups + Key Vault |
| Self-hosted | GitHub-hosted runners | Self-hosted + scale-set |
| Approval gates | Environments + branch protection | Environments + Approvals (mature) |

---

## Hands-on Checklist
- [ ] SSM SecureString: create, fetch via EC2 IAM role
- [ ] ESO on Minikube: install, create fake SecretStore, sync a secret
- [ ] Azure DevOps pipeline YAML: Docker build → ACR push → AKS deploy
