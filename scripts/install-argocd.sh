#!/bin/bash
set -e

echo "🚀 Installing ArgoCD on K3s cluster..."

# Create argocd namespace
echo "📦 Creating ArgoCD namespace..."
kubectl create namespace argocd || echo "Namespace already exists"

# Install ArgoCD
echo "📥 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get initial admin password
echo "🔑 Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "✅ ArgoCD installation complete!"
echo ""
echo "======================================"
echo "ArgoCD Access Information:"
echo "======================================"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "To access ArgoCD UI:"
echo "1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. Access: https://localhost:8080"
echo ""
echo "Or access via K3s master node:"
echo "kubectl get svc -n argocd argocd-server"
echo "======================================"

# Save password to SSM Parameter Store
echo "💾 Saving ArgoCD password to SSM Parameter Store..."
aws ssm put-parameter \
  --name "/dev/argocd/admin-password" \
  --description "ArgoCD admin password" \
  --value "$ARGOCD_PASSWORD" \
  --type "SecureString" \
  --overwrite || echo "Could not save to SSM (AWS CLI may not be configured)"

echo ""
echo "✅ Setup complete! ArgoCD is ready to deploy applications."
