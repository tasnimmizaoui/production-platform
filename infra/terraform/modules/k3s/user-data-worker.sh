#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== K3s Worker Node Setup Started ==="

# Update system
dnf update -y

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL="https://${master_private_ip}:6443" \
  K3S_TOKEN="${cluster_token}" \
  INSTALL_K3S_EXEC="agent --node-name ${environment}-k3s-worker" sh -

echo "=== K3s Worker Node Ready ==="