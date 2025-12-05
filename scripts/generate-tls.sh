set -e

echo "🔐 Generating self-signed TLS certificate"

DOMAIN="api.platform.local"
NAMESPACE="production-platform"

# Generate private key
openssl genrsa -out tls.key 2048

# Generate certificate
openssl req -new -x509 -key tls.key -out tls.crt -days 365 -subj "/CN=${DOMAIN}"

# Create Kubernetes secret
kubectl create secret tls platform-tls \
  --cert=tls.crt \
  --key=tls.key \
  --namespace=${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Cleanup
rm tls.key tls.crt

echo "✅ TLS certificate created"
