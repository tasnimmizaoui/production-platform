#!/bin/bash
# Don't exit on error - we'll handle errors explicitly
set -o pipefail

# Configuration
VPC_CIDR="10.0.0.0/16"
LOG_FILE="/var/log/nat-setup.log"
HEALTH_LOG="/var/log/nat-health.log"

# Log everything
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== NAT Instance Setup Started at $(date) ==="
echo "Environment: ${environment}"

# Error handling function
handle_error() {
    echo "ERROR: $1" >&2
    echo "Continuing with setup..."
}

# Success tracking
SETUP_SUCCESS=true

# Get instance metadata
echo "Getting instance metadata..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
REGION=$(echo $AVAILABILITY_ZONE | sed 's/[a-z]$//')

# Install packages
echo "Installing required packages..."
dnf update -y
dnf install -y iptables-services htop jq aws-cli logrotate

# Configure log rotation
cat > /etc/logrotate.d/nat-logs << EOF
$LOG_FILE $HEALTH_LOG {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0640 root root
}
EOF

# Enable IP forwarding
echo "Enabling IP forwarding..."

# Detect actual network interface (Amazon Linux 2023 uses ens5, not eth0)
PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}')
echo "Primary network interface: $PRIMARY_INTERFACE"

cat > /etc/sysctl.d/99-nat.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.$PRIMARY_INTERFACE.send_redirects = 0
EOF

# Apply sysctl settings (don't fail if one setting fails)
sysctl -p /etc/sysctl.d/99-nat.conf || handle_error "Some sysctl settings failed, but continuing"

# Verify critical setting
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
    echo "CRITICAL: IP forwarding not enabled!"
    SETUP_SUCCESS=false
fi

# Configure iptables with security
echo "Configuring iptables with security rules..."

# Flush existing rules
iptables -F
iptables -t nat -F

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# INPUT chain rules (for NAT instance itself)
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -s $VPC_CIDR -j ACCEPT  # SSH from VPC only

# FORWARD chain rules (for NAT traffic)
iptables -A FORWARD -s $VPC_CIDR -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m limit --limit 1000/minute --limit-burst 1000 -j ACCEPT
iptables -A FORWARD -j LOG --log-prefix "NAT-FORWARD-DROPPED: "

# NAT rules
iptables -t nat -A POSTROUTING -s $VPC_CIDR -j MASQUERADE

# Save rules
echo "Saving iptables rules..."
iptables-save > /etc/sysconfig/iptables
systemctl enable --now iptables

# Create enhanced health check
cat > /usr/local/bin/nat-health-check.sh << 'EOF'
#!/bin/bash
# Enhanced NAT Health Check

STATUS_FILE="/tmp/nat-status.json"

# Check IP forwarding
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
    echo "ERROR: IP forwarding disabled" >&2
    exit 1
fi

# Check iptables
if ! iptables -t nat -L POSTROUTING -n | grep -q MASQUERADE; then
    echo "ERROR: NAT rule missing" >&2
    exit 1
fi

# Check network connectivity
if ! ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "WARNING: No internet connectivity" >&2
fi

# Generate status JSON
cat > $STATUS_FILE << JSON_EOF
{
    "timestamp": "$(date -Iseconds)",
    "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)",
    "ip_forwarding": "$(cat /proc/sys/net/ipv4/ip_forward)",
    "nat_rules": "$(iptables -t nat -L POSTROUTING -n | grep -c MASQUERADE)",
    "conntrack_count": "$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 'N/A')",
    "public_ip": "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
}
JSON_EOF

echo "OK: NAT instance healthy"
exit 0
EOF

chmod +x /usr/local/bin/nat-health-check.sh

# Setup systemd service for better monitoring
cat > /etc/systemd/system/nat-health.service << EOF
[Unit]
Description=NAT Instance Health Check Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nat-health-check.sh
User=root
EOF

cat > /etc/systemd/system/nat-health.timer << EOF
[Unit]
Description=Run NAT health check every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now nat-health.timer

echo "=== NAT Instance Setup Complete at $(date) ==="
echo "NAT instance $INSTANCE_ID in $REGION is ready"
echo "VPC CIDR: $VPC_CIDR"
echo "Health checks will run every 5 minutes"

# Final status
if [ "$SETUP_SUCCESS" = true ]; then
    echo "✅ SETUP SUCCESSFUL - All critical components configured"
    exit 0
else
    echo "⚠️ SETUP COMPLETED WITH WARNINGS - Check logs above"
    exit 1
fi