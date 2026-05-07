# Day 12: GitHub Actions + Azure DevOps

## GitHub Actions Anatomy

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:       # manual trigger
  schedule:
    - cron: '0 6 * * 1'  # every Monday 6am UTC

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test

  build-and-deploy:
    needs: test            # depends on test job
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      # ... build + deploy steps
```

---

## OIDC with AWS — Modern Standard (2025-26)

### Old Way (Bad)
```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}     # long-lived, leak risk
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### OIDC Way (Correct)
```yaml
permissions:
  id-token: write      # required for OIDC
  contents: read

steps:
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/github-actions-role
    aws-region: us-east-1
    # GitHub issues JWT → AWS STS verifies → temp credentials
    # NO long-lived keys stored anywhere
```

### 5-Step OIDC Setup
1. In AWS: Create OIDC provider for `token.actions.githubusercontent.com`
2. Create IAM role with trust policy:
   ```json
   {"Condition": {"StringLike": {"token.actions.githubusercontent.com:sub": "repo:org/repo:*"}}}
   ```
3. Attach permission policies to role
4. In GitHub: Set `permissions: id-token: write`
5. Use `configure-aws-credentials@v4` with `role-to-assume`

**Interview gold:** "We moved to OIDC — no long-lived AWS keys in GitHub, credentials expire after 15 min, audit trail in CloudTrail per workflow run."

---

## Reusable Workflows + Composite Actions

### Reusable Workflow
```yaml
# .github/workflows/docker-build.yml
on:
  workflow_call:
    inputs:
      image-name:
        required: true
        type: string
    secrets:
      ECR_ROLE:
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - # ... build + push to ECR
```

```yaml
# Caller workflow
jobs:
  build:
    uses: org/.github/.github/workflows/docker-build.yml@main
    with:
      image-name: my-service
    secrets:
      ECR_ROLE: ${{ secrets.ECR_ROLE }}
```

### Composite Action
```yaml
# action.yml in your repo
runs:
  using: composite
  steps:
    - name: Setup kubectl
      shell: bash
      run: |
        curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl && mv kubectl /usr/local/bin/
    - name: Configure kubeconfig
      shell: bash
      run: aws eks update-kubeconfig --name ${{ inputs.cluster-name }}
```

---

## Matrix Builds

```yaml
strategy:
  matrix:
    node-version: [18, 20, 22]
    os: [ubuntu-latest, windows-latest]
  fail-fast: false   # don't cancel all if one fails

steps:
  - uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node-version }}
```

---

## Caching

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

# Docker layer caching
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

---

## Production CI/CD Workflow — Full Example

```yaml
name: Production Deploy

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-east-1
  ECR_REPO: 123456789.dkr.ecr.us-east-1.amazonaws.com/myapp
  EKS_CLUSTER: production

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v4
        with:
          path: ~/.npm
          key: ${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
      - run: npm ci && npm test

  build-push:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2
      - name: Build + Push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ env.ECR_REPO }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build-push
    runs-on: ubuntu-latest
    environment: production    # requires manual approval
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - run: aws eks update-kubeconfig --name ${{ env.EKS_CLUSTER }}
      - run: |
          helm upgrade --install myapp ./charts/myapp \
            --set image.tag=${{ github.sha }} \
            --namespace production \
            --atomic \
            --timeout 5m
```

---

## Azure DevOps YAML Pipeline

```yaml
trigger:
  branches:
    include: [main]

pool:
  vmImage: ubuntu-latest

variables:
  - group: production-vars    # linked to Key Vault

stages:
- stage: Build
  jobs:
  - job: BuildAndPush
    steps:
    - task: Docker@2
      inputs:
        containerRegistry: my-acr-connection
        repository: myapp
        command: buildAndPush
        tags: $(Build.BuildId)

- stage: Deploy
  dependsOn: Build
  jobs:
  - deployment: DeployToProduction
    environment: production    # has approval gate configured
    strategy:
      runOnce:
        deploy:
          steps:
          - task: HelmDeploy@0
            inputs:
              connectionType: Kubernetes Service Connection
              command: upgrade
              chartType: FilePath
              chartPath: charts/myapp
              releaseName: myapp
```

---

## Branching Strategy

| | GitFlow | Trunk-based |
|-|---------|-------------|
| Branches | main, develop, feature/*, release/*, hotfix/* | main + short-lived feature (1-2 days) |
| Release | Release branch | Tag on main |
| CI speed | Slow (many branches) | Fast (single integration point) |
| 2025-26 | Legacy, complex | **Standard for most teams** |

---

## Hands-on Checklist
- [ ] Full workflow: code → test → Docker build → ECR push → EKS deploy (OIDC)
- [ ] Reusable workflow: create + call from second repo
- [ ] Matrix build: 3 Node versions parallel
- [ ] Azure DevOps free tier: YAML pipeline with approval gate
