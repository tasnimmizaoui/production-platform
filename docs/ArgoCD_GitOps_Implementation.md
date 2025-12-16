# ArgoCD GitOps Implementation

## Overview

Transitioned from imperative push-based deployment to declarative GitOps using ArgoCD.

### Architecture Comparison

**Before (Imperative):**
```
GitHub Actions → SSH/SSM → kubectl apply → K3s Cluster
```
- Manual bash scripts
- Complex error handling
- No drift detection
- Push-based

**After (GitOps with ArgoCD):**
```
GitHub Actions → Build Images → Update Git
                                    ↓
ArgoCD watches Git → Auto-sync → K3s Cluster
```
- Declarative manifests
- Automatic sync
- Drift detection & self-healing
- Pull-based

## Implementation Steps

### 1. Install ArgoCD on K3s

Via SSM on K3s master:
```bash
# Get instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*k3s-master*" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Send installation script
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters file://install-argocd-command.json
```

Or directly on K3s master:
```bash
curl -s https://raw.githubusercontent.com/YOUR_USERNAME/production-platform/main/scripts/install-argocd.sh | bash
```

### 2. Update ArgoCD Application Manifest

Edit [argocd/application.yaml](../argocd/application.yaml) and replace:
```yaml
repoURL: https://github.com/YOUR_USERNAME/production-platform.git
```

### 3. Deploy ArgoCD Application

```bash
kubectl apply -f argocd/application.yaml
```

### 4. Access ArgoCD UI

Get admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Port forward:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access: https://localhost:8080

### 5. Verify Sync

```bash
# Check application status
kubectl get application production-platform -n argocd

# Watch sync progress
kubectl get application production-platform -n argocd -w

# View application details
kubectl describe application production-platform -n argocd
```

## How It Works

### Deployment Flow

1. **Developer pushes code** to `main` branch
2. **GitHub Actions** (.github/workflows/gitops-build.yaml):
   - Runs tests
   - Builds Docker images with short SHA tags (e.g., `abc1234`)
   - Pushes images to Docker Hub
   - Updates `k8s/overlays/prod/kustomization.yaml` with new image tags
   - Commits and pushes changes back to Git

3. **ArgoCD** (polls every 3 minutes):
   - Detects change in Git repository
   - Compares desired state (Git) vs actual state (K3s)
   - Automatically syncs changes to cluster
   - Monitors deployment health

4. **Self-Healing**:
   - If someone manually changes cluster state
   - ArgoCD detects drift
   - Reverts to Git state automatically

### Key Files

| File | Purpose |
|------|---------|
| `argocd/application.yaml` | ArgoCD Application definition |
| `argocd/README.md` | ArgoCD documentation |
| `k8s/overlays/prod/kustomization.yaml` | Image tag management |
| `k8s/overlays/prod/patches/` | Production-specific configs |
| `.github/workflows/gitops-build.yaml` | Build & update workflow |
| `scripts/install-argocd.sh` | ArgoCD installation script |

## Benefits

✅ **Declarative** - Git is the source of truth
✅ **Automated** - No manual kubectl commands
✅ **Safe** - Tests run before building images
✅ **Auditable** - Full Git history of deployments
✅ **Rollback** - Just `git revert` a commit
✅ **Drift Detection** - ArgoCD ensures cluster matches Git
✅ **Self-Healing** - Automatic reconciliation
✅ **Visibility** - Visual UI shows sync status

## Rollback

Simple as reverting a Git commit:

```bash
# Find the commit to revert
git log --oneline k8s/overlays/prod/kustomization.yaml

# Revert to previous version
git revert <commit-sha>
git push origin main

# ArgoCD will automatically deploy the previous version
```

## Monitoring

### ArgoCD CLI (Optional)

```bash
# Install ArgoCD CLI
brew install argocd  # macOS
# or download from https://argo-cd.readthedocs.io/en/stable/cli_installation/

# Login
argocd login localhost:8080

# Get application status
argocd app get production-platform

# Sync application
argocd app sync production-platform

# View application history
argocd app history production-platform
```

### Kubernetes Commands

```bash
# Application status
kubectl get application -n argocd

# View sync details
kubectl describe application production-platform -n argocd

# Check deployed resources
kubectl get all -n production-platform

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server -f
```

## Troubleshooting

### Application not syncing

```bash
# Force refresh
kubectl patch application production-platform -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Or via ArgoCD UI: Click "Refresh" button
```

### View sync errors

```bash
kubectl describe application production-platform -n argocd | grep -A 20 "Status:"
```

### Manual sync

```bash
# Sync now (don't wait for poll interval)
kubectl patch application production-platform -n argocd \
  --type merge \
  -p '{"operation":{"sync":{}}}'
```

## Next Steps

1. **Install ArgoCD** using the installation script
2. **Update application.yaml** with your GitHub username
3. **Deploy ArgoCD Application** with `kubectl apply`
4. **Push code changes** and watch ArgoCD auto-deploy
5. **Access ArgoCD UI** to monitor deployments

## Migration from Old Pipeline

The old imperative pipeline (deploy-aws-k3s.yaml) can be deleted once ArgoCD is working:

```bash
git rm .github/workflows/deploy-aws-k3s.yaml
git commit -m "Remove imperative deployment pipeline"
git push origin main
```

Keep `ci-cd-dev.yaml` for local development testing with Kind.
