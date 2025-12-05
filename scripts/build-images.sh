set -e

echo "🔨 Building Docker images for Minikube"

# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build API image
echo "Building API service..."
docker build -t production-platform-api:latest \
  -f app/api-service/Dockerfile \
  app/api-service/

# Build Worker image
echo "Building Worker service..."
docker build -t production-platform-worker:latest \
  -f app/worker-service/Dockerfile \
  app/worker-service/

echo "✅ Images built successfully"
docker images | grep production-platform
