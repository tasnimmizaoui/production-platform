# CI/CD Pipeline Implementation

## Overview

This document describes the imperative CI/CD pipeline that deploys the Production Platform to AWS K3s cluster via GitHub Actions.

## Pipeline Architecture

```
┌─────────────────┐
│  GitHub Actions │
│   (Ubuntu VM)   │
└────────┬────────┘
         │
         ├─ Quality Gate (Go tests)
         ├─ Build & Push (Docker images)
         └─ Deploy
              │
              ├─ Upload manifests to S3
              ├─ Execute deployment via SSM
              │
              ▼
         ┌─────────────────┐
         │  K3s Master     │
         │  (EC2 Instance) │
         └─────────────────┘
              │
              ├─ Download from S3
              ├─ Apply K8s manifests
              └─ Verify rollout
```

## Pipeline Jobs

### 1. Quality Gate (`quality`)

**Purpose:** Validate code quality before building images

**Steps:**
- Checkout repository
- Setup Go 1.21
- Run API service tests
- Run Worker service tests

**Exit criteria:** All tests must pass

---

### 2. Build & Push (`build`)

**Purpose:** Build Docker images and push to Docker Hub

**Steps:**
- Setup Docker Buildx
- Login to Docker Hub (using secrets)
- Build and push API image
  - Tags: `{sha}`, `latest`
- Build and push Worker image
  - Tags: `{sha}`, `latest`
- Use GitHub Actions cache for layers

**Output:** Two images ready for deployment

---

### 3. Deploy to AWS K3s (`deploy-aws`)

**Purpose:** Deploy images to K3s cluster via SSM

#### Step-by-Step Flow:

**3.1 Get K3s Master Instance**
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*k3s-master*" \
            "Name=instance-state-name,Values=running"
```

**3.2 Upload to S3**
- Create temporary bucket: `k3s-deploy-{timestamp}`
- Upload `manifests.tar.gz` (all k8s/ manifests)
- Upload `k3s-deploy.sh` (deployment script)

**3.3 Execute Deployment via SSM**
```bash
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    'aws s3 cp s3://$BUCKET/k3s-deploy.sh /tmp/',
    'chmod +x /tmp/k3s-deploy.sh',
    '/tmp/k3s-deploy.sh $BUCKET $API_IMAGE $WORKER_IMAGE $SHA'
  ]"
```

**3.4 Poll for Completion**
- Check command status every 10 seconds
- Timeout after 60 checks (10 minutes)
- Exit on success/failure

**3.5 Cleanup**
- Delete temporary S3 bucket
- Remove deployment artifacts from K3s master

**3.6 Health Check**
- Verify pod status
- Check recent events

**3.7 Rollback (on failure)**
```bash
kubectl rollout undo deployment/api -n production-platform
kubectl rollout undo deployment/worker -n production-platform
```

---

## Deployment Script (`k3s-deploy.sh`)

**Why a script?** Avoids complex JSON escaping in SSM commands.

**What it does:**
1. Downloads manifests from S3
2. Checks K3s API health
3. Applies namespace and configmap
4. Deploys Redis StatefulSet
5. Updates image tags with Git SHA
6. Deploys API and Worker
7. Waits for rollout completion
8. Displays pod status
9. Cleans up temporary files

**Key features:**
- `--validate=false`: Skip slow OpenAPI validation (avoids TLS timeouts on t3.micro)
- `--request-timeout=60s`: Extended timeout for resource-constrained cluster
- `set -e`: Exit on first error
- Health checks: Verifies K3s API before deployment

---

## Why Imperative Pipeline?

### Decision Context

We evaluated three approaches:

| Approach | Resource Usage | Complexity | Outcome |
|----------|---------------|------------|---------|
| **ArgoCD** | 500-700MB RAM, 7 pods | High | ❌ Failed - cluster instability |
| **FluxCD** | 50-100MB RAM, 3 pods | Medium | ❌ CrashLoopBackOff - initialization issues |
| **Imperative** | 0MB (no controllers) | Low | ✅ Success |

### Why Imperative Works

**Resource Efficiency:**
- No 24/7 controllers consuming RAM/CPU
- Deploys only when triggered
- Perfect for t3.micro (2GB RAM) constraints

**Simplicity:**
- Direct kubectl apply
- No CRDs or operators
- Easy to debug

**Reliability:**
- No GitOps reconciliation loops
- No cluster-side dependencies
- Works on fresh/stressed clusters

**Trade-offs Accepted:**
- No automatic drift correction
- Manual trigger required (GitHub Actions)
- No GitOps declarative benefits

---

## IAM Permissions Required

### K3s Master Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::k3s-deploy-*",
        "arn:aws:s3:::k3s-deploy-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:UpdateInstanceInformation",
        "ssmmessages:*",
        "ec2messages:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### GitHub Actions (Secrets)
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

---

## Workflow Triggers

```yaml
workflow_dispatch:  # Manual trigger only (commented out automatic triggers)
```

**Why manual only?**
- Prevents accidental deployments
- Gives control over when to deploy
- Avoids unnecessary builds on non-deployment commits

**To enable automatic deployment:**
Uncomment the `push` trigger:
```yaml
push:
  branches: [ main ]
  paths:
    - 'app/**'
    - '.github/workflows/deploy-aws-k3s.yaml'
```

---

## Deployment Flow

```
1. Developer pushes code
   ↓
2. Manually trigger "Deploy to AWS K3s (Imperative)" in GitHub Actions
   ↓
3. Quality Gate runs (Go tests)
   ↓
4. Build images with Git SHA tag
   ↓
5. Push to Docker Hub
   ↓
6. Upload manifests + script to S3
   ↓
7. SSM executes deployment on K3s master
   ↓
8. K3s downloads from S3
   ↓
9. kubectl apply manifests
   ↓
10. Wait for rollout completion
   ↓
11. Health check
   ↓
12. Cleanup S3 bucket
   ↓
13. ✅ Deployment complete
```

---

## Monitoring Deployment

**During GitHub Actions run:**
```
Actions tab → Deploy to AWS K3s (Imperative) → View logs
```

**On K3s master (via SSM):**
```bash
# Watch pods
kubectl get pods -n production-platform -w

# Check deployment status
kubectl rollout status deployment/api -n production-platform
kubectl rollout status deployment/worker -n production-platform

# View events
kubectl get events -n production-platform --sort-by=.lastTimestamp

# Check logs
kubectl logs -n production-platform deployment/api
kubectl logs -n production-platform deployment/worker
```

---

## Troubleshooting

### Pipeline fails at S3 upload
- **Issue:** AWS credentials invalid
- **Fix:** Check GitHub Secrets for `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

### SSM command times out
- **Issue:** K3s master not responding
- **Fix:** Restart K3s: `sudo systemctl restart k3s`

### TLS handshake timeout
- **Issue:** K3s API overloaded
- **Fix:** Solved it by  using `--validate=false` and `--request-timeout=60s`. 

### Worker/API pods not starting
- **Issue:** Image pull errors or resource limits
- **Fix:** 
  - Check Docker Hub credentials
  - Verify image exists: `docker pull {image}:{sha}`
  - Check pod logs: `kubectl logs -n production-platform pod/{name}`

### Rollout stuck
- **Issue:** Insufficient resources or readiness probe failing
- **Fix:** 
  - Check node resources: `kubectl top nodes`
  - Describe pod: `kubectl describe pod -n production-platform {pod-name}`

---

## Success Metrics

**Deployment Successful When:**
- ✅ All pods in `Running` state
- ✅ Deployments show `2/2` (API) and `1/1` (Worker) ready
- ✅ Redis StatefulSet shows `1/1` ready
- ✅ No CrashLoopBackOff or ImagePullBackOff
- ✅ Readiness probes passing

**Example healthy output:**
```
NAME                       READY   STATUS    RESTARTS   AGE
pod/api-59b4dcf8b4-49c9m   1/1     Running   0          10m
pod/api-59b4dcf8b4-j72bc   1/1     Running   0          10m
pod/redis-0                1/1     Running   0          10m
pod/worker-7d8f9c5b-xyz    1/1     Running   0          10m
```

---

## Future Improvements

**When scaling beyond t3.micro:**
1. Re-evaluate FluxCD for automatic GitOps
2. Add HPA (Horizontal Pod Autoscaling)
3. Implement PDB (Pod Disruption Budgets)
4. Add Ingress for external access
5. Enable automatic pipeline triggers on push

**Key learnings :**
- Pragmatic engineering decisions
- Tool evaluation (ArgoCD → FluxCD → Imperative)
- Documenting trade-offs and constraints
- Resource-aware architecture

---

## Files Reference

| File | Purpose |
|------|---------|
| `.github/workflows/deploy-aws-k3s.yaml` | Main pipeline definition |
| `scripts/k3s-deploy.sh` | Deployment script executed on K3s master |
| `k8s/base/` | Kubernetes manifests (namespace, configmap, deployments, services) |
| `infra/terraform/modules/k3s/` | K3s cluster infrastructure |
| `docs/ArgoCD_to_FluxCD_Migration.md` | GitOps evaluation documentation |

---

**Last Updated:** December 17, 2025  
**Pipeline Status:** ✅ Production Ready
