set -e

echo "🚀 Deploying to Kubernetes"

# Create namespace
kubectl apply -f k8s/base/namespace.yaml

# Apply ConfigMap
kubectl apply -f k8s/base/configmap.yaml

# Deploy Redis
kubectl apply -f k8s/base/redis/

# Wait for Redis
echo "Waiting for Redis..."
kubectl wait --namespace production-platform \
  --for=condition=ready pod \
  --selector=app=redis \
  --timeout=120s

# Deploy API
kubectl apply -f k8s/base/api/

# Deploy Worker
kubectl apply -f k8s/base/worker/

# Wait for deployments
echo "Waiting for API deployment..."
kubectl wait --namespace production-platform \
  --for=condition=available deployment/api \
  --timeout=120s

echo "Waiting for Worker deployment..."
kubectl wait --namespace production-platform \
  --for=condition=available deployment/worker \
  --timeout=120s

# Apply HPA
#kubectl apply -f k8s/base/hpa/

# Apply PDB
#kubectl apply -f k8s/base/pdb/

# Generate self-signed certificate for Ingress
echo "Generating TLS certificate..."
./scripts/generate-tls.sh

# Apply Ingress
kubectl apply -f k8s/base/ingress/

echo "✅ Deployment complete"
echo ""
echo "Check status: kubectl get all -n production-platform"
echo "View logs: kubectl logs -n production-platform -l app=api -f"
