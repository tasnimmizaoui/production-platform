#!/bin/bash
set -e

echo "🔐 Generating TLS certificate with SANs"

DOMAIN="api.platform.local"
NAMESPACE="production-platform"

# Generate private key
openssl genrsa -out tls.key 2048

# Create config file with SAN
cat > csr.conf <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
C = US
ST = California
L = San Francisco
O = Platform
OU = Development
CN = api.platform.local

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = api.platform.local
DNS.2 = *.platform.local
EOF

# Generate CSR
openssl req -new -key tls.key -out tls.csr -config csr.conf

# Generate self-signed certificate with SAN
openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt \
  -extfile csr.conf -extensions req_ext

# Create Kubernetes secret
kubectl create secret tls platform-tls \
  --cert=tls.crt \
  --key=tls.key \
  --namespace=${NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Cleanup
rm -f tls.key tls.crt tls.csr csr.conf

echo "✅ TLS certificate with SANs created"