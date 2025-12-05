set -e

echo "🧪 Testing Kubernetes deployment"

NAMESPACE="production-platform"

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

# Add to /etc/hosts if not present
if ! grep -q "api.platform.local" /etc/hosts; then
  echo "$MINIKUBE_IP api.platform.local" | sudo tee -a /etc/hosts
fi

# Test API health
echo "Testing API health..."
curl -k https://api.platform.local/health

# Create test task
echo -e "\nCreating test task..."
TASK_ID=$(curl -k -s -X POST https://api.platform.local/tasks \
  -H "Content-Type: application/json" \
  -d '{"payload":"kubernetes-test"}' | jq -r '.task_id')

echo "Task created: $TASK_ID"

# Wait for processing
sleep 5

# Check task status
echo -e "\nChecking task status..."
curl -k -s https://api.platform.local/tasks/$TASK_ID | jq .

echo -e "\n✅ Deployment test passed"