set -e

echo "🧹 Cleaning up Kubernetes resources"

kubectl delete namespace production-platform --ignore-not-found

echo "✅ Cleanup complete"
