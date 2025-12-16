# ArgoCD Configuration

This directory contains ArgoCD Application manifests for GitOps-based deployment.

## Architecture

```
GitHub Repository (Source of Truth)
         ↓
   ArgoCD watches main branch
         ↓
   Automatically syncs to K3s cluster
         ↓
   Self-healing & drift detection
```

## Installation

### 1. Install ArgoCD on K3s cluster

From your local machine with `kubeconfig` configured:
```bash
./scripts/install-argocd.sh
```

Or via SSM on K3s master:
```bash
# Get K3s master instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*k3s-master*" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Execute installation via SSM
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[$(curl -s https://raw.githubusercontent.com/tasnimmizaoui/production-platform/main/scripts/install-argocd.sh | base64 -w 0)]"
```

### 2. Deploy ArgoCD Application

**Update the repository URL** in `application.yaml`:
```yaml
repoURL: https://github.com/tasnimmizaoui/production-platform.git
```

Then apply:
```bash
kubectl apply -f argocd/application.yaml
```

### 3. Access ArgoCD UI

**Option A: Port Forward (Local access)**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Then open: https://localhost:8080

**Option B: Ingress (Production)**
Create an Ingress resource for external access (TLS recommended)

### 4. Login

Username: `admin`
Password: Retrieved during installation or from SSM:
```bash
aws ssm get-parameter --name /dev/argocd/admin-password --with-decryption --query 'Parameter.Value' --output text
```

## How It Works

### Deployment Flow

1. **Developer pushes code** → GitHub Actions builds Docker images
2. **GitHub Actions updates** `k8s/overlays/prod/kustomization.yaml` with new image SHA
3. **ArgoCD detects change** in Git repository (polls every 3 minutes by default)
4. **ArgoCD syncs** - applies changes to K3s cluster
5. **Self-healing** - if someone manually changes cluster, ArgoCD reverts to Git state

### Sync Policies

- **Automated sync**: Enabled - changes auto-deploy
- **Prune**: Enabled - deletes resources removed from Git
- **Self-heal**: Enabled - reverts manual cluster changes
- **Retry**: Up to 5 attempts with exponential backoff

### Rollback

Just revert the Git commit:
```bash
git revert HEAD
git push origin main
```
ArgoCD automatically syncs the previous state.

## Monitoring

### Check Application Status
```bash
kubectl get application -n argocd
```

### View Sync Status
```bash
kubectl describe application production-platform -n argocd
```

### Watch ArgoCD Logs
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

## Benefits Over Imperative Deployment

| Feature | Old Pipeline | ArgoCD |
|---------|-------------|--------|
| Deployment method | Push (imperative) | Pull (declarative) |
| Drift detection | ❌ None | ✅ Automatic |
| Rollback | Complex scripts | Git revert |
| Visibility | Logs only | Visual UI + CLI |
| Self-healing | ❌ None | ✅ Automatic |
| Audit trail | Limited | Full Git history |
| Configuration | Bash scripts | Kubernetes manifests |

## Troubleshooting

### Application not syncing
```bash
# Force sync
kubectl patch application production-platform -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### View application details
```bash
kubectl get application production-platform -n argocd -o yaml
```

### Check ArgoCD health
```bash
kubectl get pods -n argocd
```
