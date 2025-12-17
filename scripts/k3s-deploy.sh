#!/bin/bash
set -e

# This script is executed on the K3s master via SSM
# Arguments: $1=S3_BUCKET, $2=API_IMAGE, $3=WORKER_IMAGE, $4=GIT_SHA

S3_BUCKET=$1
API_IMAGE=$2
WORKER_IMAGE=$3
GIT_SHA=$4

echo "📥 Downloading manifests from S3..."
cd /tmp
aws s3 cp s3://${S3_BUCKET}/manifests.tar.gz .
tar xzf manifests.tar.gz

cd k8s/base

echo "📦 Starting deployment to K3s..."
echo "🏥 Checking K3s health..."
kubectl get nodes || { echo '❌ K3s API not responding'; exit 1; }

echo "🔧 Creating namespace and configmap..."
kubectl apply --validate=false -f namespace.yaml
kubectl apply --validate=false -f configmap.yaml

echo "🔴 Deploying Redis..."
kubectl apply --validate=false -f redis/

echo "⏳ Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n production-platform --timeout=120s || true

echo "🔄 Updating image tags in manifests..."
sed -i "s|image: .*/production-platform-api:.*|image: ${API_IMAGE}:${GIT_SHA}|g" api/deployment.yaml
sed -i "s|image: .*/production-platform-worker:.*|image: ${WORKER_IMAGE}:${GIT_SHA}|g" worker/deployment.yaml

echo "🚀 Deploying API service..."
kubectl apply --validate=false -f api/

echo "⚙️ Deploying Worker service..."
kubectl apply --validate=false -f worker/

echo "⏳ Waiting for API rollout..."
kubectl rollout status deployment/api -n production-platform --timeout=180s

echo "⏳ Waiting for Worker rollout..."
kubectl rollout status deployment/worker -n production-platform --timeout=180s

echo "✅ Deployment complete! Pod status:"
kubectl get pods -n production-platform -o wide

echo ""
echo "📊 Deployment details:"
kubectl get all -n production-platform

echo ""
echo "🧹 Cleanup..."
cd /tmp && rm -rf k8s manifests.tar.gz k3s-deploy.sh

echo "✅ All done!"
