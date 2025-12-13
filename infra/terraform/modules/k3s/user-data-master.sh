#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== K3s Master Node Setup Started ==="

# Update system
dnf update -y

# Install K3s server
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --disable servicelb \
  --write-kubeconfig-mode 644 \
  --token ${cluster_token} \
  --node-name ${environment}-k3s-master" sh -

# Wait for K3s to be ready
echo "Waiting for K3s to start..."
until kubectl get nodes &>/dev/null; do
  sleep 5
done

echo "=== K3s Master Ready ==="
kubectl get nodes

echo "=== Setup Complete ==="