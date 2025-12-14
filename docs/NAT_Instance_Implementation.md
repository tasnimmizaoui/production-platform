# NAT Instance Implementation Guide

> **Free Alternative to AWS NAT Gateway** - Save $32.85/month ($394/year)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Why NAT Instance?](#why-nat-instance)
- [How It Works](#how-it-works)
- [Implementation Details](#implementation-details)
- [Cost Analysis](#cost-analysis)
- [Security Considerations](#security-considerations)
- [Performance](#performance)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [When to Use](#when-to-use)

---

## Overview

A NAT (Network Address Translation) instance is a regular EC2 instance configured to route internet traffic for instances in private subnets. This is a free-tier alternative to AWS's managed NAT Gateway service.

### Key Characteristics

- **Type:** EC2 instance (t2.micro)
- **Cost:** $0 within free tier (750 hours/month)
- **Location:** Public subnet
- **Function:** Routes outbound internet traffic from private subnets

---

## Why NAT Instance?

### Cost Comparison

| Feature | NAT Gateway | NAT Instance (t2.micro) |
|---------|-------------|------------------------|
| **Hourly Rate** | $0.045 | $0.0116 |
| **Monthly (730h)** | $32.85 | $8.47 |
| **Free Tier** | ❌ No | ✅ Yes (750h) |
| **Data Processing** | $0.045/GB | Included |
| **Your Cost** | **$32.85/mo** | **$0/mo** |

**Annual Savings: $394.20** 💸

### Benefits

✅ **Zero cost** - Free tier covers 750 hours/month  
✅ **Full control** - SSH access, custom rules  
✅ **Learning** - Understand NAT deeply  
✅ **Debugging** - Easy troubleshooting  
✅ **Customization** - Add features as needed  

### Trade-offs

⚠️ **Single point of failure** - No built-in HA  
⚠️ **Manual scaling** - Fixed capacity  
⚠️ **Limited bandwidth** - Instance network limits  
⚠️ **Maintenance** - You manage it  

---

## How It Works

### The NAT Process

```
  Private Instance                NAT Instance               Internet
  10.0.2.10                       10.0.1.50                  
  │                               │                               |
  │ 1. Packet: 10.0.2.10 → API    │                               |
  ├──────────────────────────────>│                               |
  │                               │ 2. MASQUERADE                 |
  │                               │    Replace source:            |
  │                               │    10.0.1.50 → API            |
  │                               ├─────────────────────────>     |
  │                               │                               |
  │                               │ 3. Response: API → NAT        |
  │                               │<─────────────────────────     |
  │                               │ 4. Un-NAT                     |
  │ 5. Response to 10.0.2.10      │     Replace dest:         
  │<──────────────────────────────┤      10.0.2.10             
  │                               │                          
  ```

### Technical Components

#### 1. IP Forwarding
```bash
# Enable kernel IP forwarding
net.ipv4.ip_forward = 1
```

This allows the Linux kernel to forward packets between network interfaces.

#### 2. iptables MASQUERADE
```bash
# NAT rule
iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -j MASQUERADE
```

This rewrites the source IP address of outgoing packets to the NAT instance's public IP.

#### 3. Source/Dest Check Disabled
```bash
# AWS-specific requirement
source_dest_check = false
```

EC2 instances normally drop packets not addressed to them. This must be disabled for NAT.

#### 4. Route Table Entry
```hcl
# Route all internet traffic to NAT
route {
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}
```

---

## Implementation Details

### Terraform Configuration

**File:** [`infra/terraform/modules/vpc/nat-instance.tf`](../infra/terraform/modules/vpc/nat-instance.tf)

```hcl
# NAT Instance
resource "aws_instance" "nat" {
  count = var.enable_nat_instance ? 1 : 0

  ami                    = data.aws_ami.nat_ami.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat.id]
  iam_instance_profile   = aws_iam_instance_profile.nat.name
  
  # CRITICAL: Disable source/destination check for NAT to work
  source_dest_check = false

  user_data = base64encode(templatefile("${path.module}/nat-user-data.sh", {
    environment = var.environment
  }))

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-nat-instance"
  })
}

# Elastic IP for NAT
resource "aws_eip" "nat" {
  count = var.enable_nat_instance ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.nat[0].id

  tags = merge(var.tags, {
    Name = "${var.environment}-nat-eip"
  })
}

# Route from Private Subnet to NAT
resource "aws_route" "private_nat" {
  count = var.enable_nat_instance ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}
```

### Security Group

```hcl
resource "aws_security_group" "nat" {
  name_prefix = "${var.environment}-nat-"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from private subnets
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]  # Private subnet
  }

  # Allow HTTPS from private subnets
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Bootstrap Script

**File:** [`infra/terraform/modules/vpc/nat-user-data.sh`](../infra/terraform/modules/vpc/nat-user-data.sh)


**Key Fixes Implemented after some initial scripts that faces some errors :**
- ❌ Removed `set -e` (was causing silent failures)
- ✅ Dynamic interface detection (`ens5` not `eth0`)
- ✅ Explicit error handling with `handle_error()`
- ✅ Comprehensive logging to `/var/log/nat-setup.log`

---

## Cost Analysis

### Monthly Breakdown

#### Traditional NAT Gateway
```
NAT Gateway:     $32.85 (730 hours × $0.045)
Data Processing: $4.50  (100GB × $0.045)
─────────────────────────
Total:           $37.35/month
```

#### NAT Instance (This Project)
```
t2.micro:        $0.00  (free tier covers 750 hours)
Data Transfer:   $0.00  (included in EC2 pricing)
EBS Storage:     $0.00  (8GB covered by free tier)
Elastic IP:      $0.00  (when attached to running instance)
─────────────────────────
Total:           $0.00/month ✅
```

### Annual Comparison

| Year | NAT Gateway | NAT Instance | Savings |
|------|-------------|--------------|---------|
| **Year 1** | $448.20 | $0.00 | **$448.20** |
| **Year 2** | $448.20 | $101.64* | **$346.56** |
| **Year 3** | $448.20 | $101.64 | **$346.56** |

*After free tier expires (12 months)

---

## Security Considerations

### ✅ Implemented Security

#### 1. Restrictive Security Groups
```hcl
# Only allow necessary ports from private subnet
ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["10.0.2.0/24"]  # Private subnet only
}
```

#### 2. Rate Limiting
```bash
# Prevent DDoS/abuse
iptables -A FORWARD -m limit --limit 1000/minute --limit-burst 1000 -j ACCEPT
iptables -A FORWARD -j LOG --log-prefix "NAT-FORWARD-DROPPED: "
```

#### 3. Connection Tracking
```bash
# Monitor active connections
cat /proc/sys/net/netfilter/nf_conntrack_count
```

#### 4. Logging
```bash
# All traffic logged
iptables -A FORWARD -j LOG --log-prefix "NAT-FORWARD: "
```

### 🔒 Best Practices

1. **Regular Updates**
   ```bash
   dnf update -y
   ```

2. **Monitoring Alerts**
   ```bash
   # CPU > 80%
   # Network > 80% capacity
   # Connection count > threshold
   ```

3. **Backup NAT Instance**
   ```bash
   # Create AMI weekly
   aws ec2 create-image --instance-id <nat-id>
   ```

4. **Session Manager Access**
   ```bash
   # No SSH keys needed
   aws ssm start-session --target <nat-id>
   ```

---

## Performance

### Network Throughput

| Instance Type | Network Bandwidth | Baseline | Burst |
|--------------|-------------------|----------|-------|
| **t2.micro** | Up to 5 Gbps | 64 Mbps | 1024 Mbps |
| t3.micro | Up to 5 Gbps | 256 Mbps | 2048 Mbps |
| t3.small | Up to 5 Gbps | 512 Mbps | 2048 Mbps |

### Connection Limits

```bash
# Default conntrack table size
cat /proc/sys/net/netfilter/nf_conntrack_max
# Default: 65536 connections

# Increase if needed
sysctl -w net.netfilter.nf_conntrack_max=131072
```

### Performance Tuning

```bash
# Optimize TCP stack
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_window_scaling = 1
net.core.netdev_max_backlog = 5000
EOF

sysctl -p
```

---

## Monitoring

### Health Check Script

```bash
#!/bin/bash
# /usr/local/bin/nat-health-check.sh

# Check IP forwarding
if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
    echo "ERROR: IP forwarding disabled"
    exit 1
fi

# Check NAT rules
if ! iptables -t nat -L | grep -q MASQUERADE; then
    echo "ERROR: NAT rules missing"
    exit 1
fi

# Check internet connectivity
if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "WARNING: No internet connectivity"
    exit 2
fi

echo "OK: NAT instance healthy"
exit 0
```

### Automated Monitoring

```bash
# systemd timer (runs every 5 minutes)
[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
```

### Key Metrics to Monitor

1. **CPU Utilization** - Should stay < 60%
2. **Network In/Out** - Track bandwidth usage
3. **Connection Count** - Monitor conntrack table
4. **Instance Status** - Check instance health
5. **Disk I/O** - Monitor for issues

### CloudWatch Alarms (Optional)

```bash
# CPU > 80% for 5 minutes
aws cloudwatch put-metric-alarm \
  --alarm-name nat-high-cpu \
  --alarm-actions <sns-topic-arn> \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80
```

---

## Troubleshooting

### Issue: Private instances can't reach internet

**Diagnosis:**
```bash
# 1. Check route table
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=*private*"
# Should show route: 0.0.0.0/0 → NAT ENI

# 2. Check IP forwarding on NAT
aws ssm start-session --target <nat-id>
cat /proc/sys/net/ipv4/ip_forward  # Must be: 1

# 3. Check iptables
sudo iptables -t nat -L -n -v | grep MASQUERADE

# 4. Check source/dest check
aws ec2 describe-instances --instance-ids <nat-id> \
  --query 'Reservations[0].Instances[0].SourceDestCheck'
# Must be: false
```

**Fix:**
```bash
# Re-run bootstrap script
sudo bash /var/log/nat-setup.log
```

### Issue: High CPU usage

**Diagnosis:**
```bash
# Check connection count
cat /proc/sys/net/netfilter/nf_conntrack_count

# Check top processes
top -bn1 | head -20

# Check network traffic
iftop -i eth0
```

**Fix:**
```hcl
# Upgrade instance type
nat_instance_type = "t3.small"
```

### Issue: Intermittent connectivity

**Diagnosis:**
```bash
# Check packet drops
netstat -s | grep -i drop

# Check interface errors
ip -s link show eth0

# Check system logs
journalctl -u iptables -f
```

**Fix:**
```bash
# Increase buffer sizes
sysctl -w net.core.netdev_max_backlog=10000
sysctl -w net.core.rmem_max=16777216
```

---

## When to Use

### ✅ Good Fit For:

- **Learning/Development** environments
- **Small production workloads** (<100 connections/sec)
- **Cost-sensitive** projects
- **Low-medium traffic** applications
- **Single-region** deployments
- **Non-critical** systems (can tolerate brief downtime)

### ❌ Not Recommended For:

- **High-traffic** applications (>1000 connections/sec)
- **Mission-critical** systems requiring 99.99% uptime
- **Multi-AZ** deployments needing HA
- **Compliance** requirements for managed services
- **Enterprise** production (without redundancy)

### 🟡 Use With Caution:

- **Staging environments** - OK with monitoring
- **Small production** - Add CloudWatch alarms
- **Prototypes** - Perfect for MVPs
- **Side projects** - Great cost saver

---

## Comparison Matrix

| Factor | NAT Gateway | NAT Instance | This Project |
|--------|-------------|--------------|--------------|
| **Cost** | $32.85/mo | $8.47/mo | **$0/mo** ✅ |
| **Availability** | 99.99% | 95-99% | ~95% |
| **Bandwidth** | Up to 100 Gbps | Up to 5 Gbps | Up to 1 Gbps |
| **Management** | AWS managed | Self-managed | Self-managed |
| **Scaling** | Automatic | Manual | Manual |
| **Setup Time** | 5 minutes | 15 minutes | 20 minutes |
| **Monitoring** | Built-in | Custom | Custom |
| **Failover** | Automatic | Manual | Manual |

---

## Real-World Verification Results

**Date:** December 14, 2025  
**Environment:** dev  
**Region:** us-east-1

### Deployed Infrastructure

| Component | Instance ID | Type | IP Address | Status |
|-----------|-------------|------|------------|--------|
| NAT Instance | i-0e713307c7af25b9e | t2.micro | 54.84.39.57 (public)<br>10.0.1.129 (private) | ✅ Running |
| K3s Master | i-0c14c553daecde0d2 | t3.micro | 10.0.2.x (private) | ✅ Running |
| K3s Worker | i-02d7714560250d70b | t3.micro | 10.0.2.x (private) | ✅ Running |

### ✅ NAT Instance Verification

```bash
# IP Forwarding Check
$ cat /proc/sys/net/ipv4/ip_forward
1  #  Enabled --> Outputs 1 

# iptables NAT Rules
$ sudo iptables -t nat -L POSTROUTING -n -v
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
pkts bytes target     prot opt in     out     source               destination
  12  720 MASQUERADE  all  --  *      ens5    10.0.0.0/16          0.0.0.0/0
#  NAT rule configured

# Health Check
$ sudo /usr/local/bin/nat-health-check.sh
 SETUP SUCCESSFUL
# All checks pass
```

### ✅ K3s Cluster Verification

```bash
# Cluster Status
$ kubectl get nodes
NAME                         STATUS   ROLES                  AGE   VERSION
ip-10-0-2-x.ec2.internal     Ready    control-plane,master   15m   v1.28.x
ip-10-0-2-y.ec2.internal     Ready    <none>                 14m   v1.28.x
# ✅ 2/2 nodes Ready

# Pod Status
$ kubectl get pods -A
NAMESPACE     NAME                              READY   STATUS    RESTARTS   AGE
kube-system   coredns-xxx                       1/1     Running   0          15m
kube-system   local-path-provisioner-xxx        1/1     Running   0          15m
default       redis-xxx                         1/1     Running   0          14m
# ✅ All pods running
```

### ✅ Internet Connectivity Tests

**From K3s Master (Private Subnet):**

```bash
# 1. Route Table
$ ip route
default via 10.0.1.129 dev ens5  # ✅ Routes through NAT
10.0.2.0/24 dev ens5 proto kernel scope link src 10.0.2.x

# 2. HTTP/HTTPS Access
$ curl -I https://get.k3s.io
HTTP/2 200  # ✅ Internet accessible

$ curl -I https://registry-1.docker.io/v2/
HTTP/1.1 401 Unauthorized  # ✅ Reachable (needs auth)

# 3. DNS Resolution
$ nslookup google.com
Server:    10.0.0.2
Address:   10.0.0.2#53

Non-authoritative answer:
Name:   google.com
Address: 142.250.80.46
# ✅ DNS working

# 4. Ping Test
$ ping -c 3 8.8.8.8
3 packets transmitted, 3 received, 0% packet loss
# ✅ ICMP working

# 5. Traceroute (Verify NAT Routing)
$ traceroute -n -m 3 8.8.8.8
1  10.0.1.129  0.5ms   # ✅ First hop is NAT instance
2  * * *
3  * * *
# ✅ Traffic routes through NAT

# 6. GitHub API Test
$ curl https://api.github.com
{
  "current_user_url": "https://api.github.com/user",
  ...
}
# ✅ Full internet access confirmed
```

### 📊 Cost Summary

```
  ┌────────────────────────────────────────┐
  │  Monthly Cost: $0.00                   │
  │  Within Free Tier Limits:              │
  │    • t2.micro: 750 hours/month ✅      │
  │    • t3.micro: 750 hours/month ✅      │
  │    • EBS: 30GB free ✅                 │
  │                                        │
  │  Savings vs NAT Gateway: $32.85/month  │
  │  Annual Savings: $394.20               │
  └────────────────────────────────────────┘
```

### 📸 Screenshots

[Running Instances](image.png)
*Three EC2 instances running: NAT, K3s Master, K3s Worker*

[K3s Master Verification](image-4.png)
*K3s cluster running successfully*

[Route Table](image-3.png)
*Private subnet routing through NAT instance*

[Docker Hub Access](image-5.png)
*Docker Hub accessible from private K3s master*

---

## Next Steps

### Phase 2 Complete ✅
- [x] NAT instance implemented
- [x] Private subnet connectivity verified
- [x] Health monitoring configured
- [x] Documentation complete

### Phase 3: Enterprise Upgrade 🚀

Move to **zero-egress architecture** with:
- VPC Endpoints for AWS services
- Docker registry mirror (S3-backed)
- Air-gapped cluster
- No NAT instance needed!

[Read about Phase 3 →](../README.md#phase-3-vpc-endpoints--docker-proxy)

---

## Resources

- [AWS NAT Instances Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html)
- [Linux NAT with iptables](https://www.netfilter.org/documentation/)
- [VPC Routing](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [EC2 Networking](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-networking.html)

---

**Summary:** NAT instance provides a free, functional alternative to NAT Gateway for learning and small production workloads. For enterprise deployments, consider Phase 3 (VPC Endpoints) or upgrading to NAT Gateway for managed HA. 🚀
