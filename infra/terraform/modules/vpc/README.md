# VPC Module - Free Tier Optimized

A production-ready AWS VPC module designed for **$0 monthly cost** using free tier resources and cost-optimization strategies.

## 🎯 Key Features

- ✅ **Zero-cost networking** - Completely free within AWS free tier
- ✅ **NAT Instance** - $0 alternative to $32/month NAT Gateway
- ✅ **Private subnet isolation** - Production-grade security
- ✅ **VPC Flow Logs** - Free monitoring (S3 storage < 5GB)
- ✅ **Session Manager access** - No SSH keys or bastion hosts needed
- ✅ **VPC Endpoints** - Free S3 access without internet
- ✅ **Production-ready** - Suitable for small to medium workloads

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────┐
│ VPC (10.0.0.0/16)                                   │
│                                                     │
│  ┌──────────────────────────────────────┐           │
│  │ Public Subnet (10.0.1.0/24)          │           │
│  │                                      │           │
│  │  ┌─────────────────┐                 │           │
│  │  │ NAT Instance    │ ← Elastic IP    │────────── ┼─→ Internet
│  │  │ (t2.micro)      │    (Public)     │           │
│  │  └────────┬────────┘                 │           │
│  │           │ IP Forward + iptables    │           │
│  └───────────┼──────────────────────────┘           │
│              │ MASQUERADE                           │
│              ↓                                      │
│  ┌──────────────────────────────────────┐           │
│  │ Private Subnet (10.0.2.0/24)         │           │
│  │                                      │           │
│  │  ┌─────────────┐  ┌─────────────┐    │           │
│  │  │ K3s Master  │  │ K3s Worker  │    │           │
│  │  │ (no public  │  │ (no public  │    │           │
│  │  │    IP)      │  │    IP)      │    │           │
│  │  └─────────────┘  └─────────────┘    │           │
│  │                                      │           │
│  └──────────────────────────────────────┘           │
│                     ↓                               │
│          ┌──────────────────────┐                   │
│          │ S3 VPC Endpoint      │ (FREE)            │ 
│          │ (Gateway Type)       │                   │
│          └──────────┬───────────┘                   │
└─────────────────────┼───────────────────────────────┘
                      ↓
                  S3 Bucket
              (Flow Logs, Registry)
```

---

## 💰 Cost Comparison

### Traditional AWS Setup vs. This Module

| Component | AWS Standard | This Module | Savings |
|-----------|-------------|-------------|---------|
| **NAT Gateway** | $32.85/month | $0 (t2.micro) | $32.85 |
| **Bastion Host** | $8.47/month | $0 (Session Manager) | $8.47 |
| **VPC** | Free | Free | $0 |
| **Internet Gateway** | Free | Free | $0 |
| **S3 VPC Endpoint** | Free | Free | $0 |
| **Flow Logs (S3)** | Free (<5GB) | Free (<5GB) | $0 |
| **EBS Storage** | $0.80 (8GB) | Free tier | $0 |
| **Data Transfer** | $0.09/GB | $0.09/GB | $0 |
| **TOTAL** | **$42.12/month** | **$0/month** | **$42.12** |

**Annual Savings: $505.44** 💸

---

## 🏗️ Components Created

### Networking
- ✅ VPC with DNS support
- ✅ Public subnet (1 AZ)
- ✅ Private subnet (1 AZ)
- ✅ Internet Gateway
- ✅ Route tables (public + private)
- ✅ S3 VPC Gateway Endpoint

### NAT Instance (Core Innovation)
- ✅ t2.micro EC2 instance (free tier)
- ✅ Elastic IP
- ✅ Security group (restrictive)
- ✅ IAM role (Session Manager)
- ✅ iptables NAT configuration
- ✅ IP forwarding enabled
- ✅ Health check monitoring
- ✅ Automated log rotation

### Security
- ✅ Network ACLs (public subnet)
- ✅ Security groups (K3s, NAT, VPC endpoints)
- ✅ VPC Flow Logs to S3
- ✅ Encrypted EBS volumes
- ✅ Session Manager (no SSH keys)

### Monitoring
- ✅ VPC Flow Logs (S3)
- ✅ NAT health checks (systemd timer)
- ✅ CloudWatch-ready metrics

---

## 🔧 NAT Instance Details

### How It Works

The NAT instance is a regular EC2 instance configured to route traffic:

1. **IP Forwarding** - Linux kernel forwards packets between interfaces
2. **iptables MASQUERADE** - Rewrites source IPs for outbound traffic
3. **Source/Dest Check Disabled** - Allows forwarding of non-local packets
4. **Route Table Entry** - Private subnet routes `0.0.0.0/0` to NAT instance

### Bootstrap Process

```bash
# Enable IP forwarding
net.ipv4.ip_forward = 1

# Configure NAT with iptables
iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -j MASQUERADE

# Security rules
iptables -A FORWARD -s 10.0.0.0/16 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Rate limiting (1000 connections/min)
iptables -A FORWARD -m limit --limit 1000/minute -j ACCEPT
```

### Health Monitoring

Automated health checks run every 5 minutes:
- IP forwarding status
- iptables NAT rules presence
- Internet connectivity
- Connection tracking stats

Logs available at:
- `/var/log/nat-setup.log` - Setup process
- `/var/log/nat-health.log` - Health check results

---

## 🚀 Usage

### Basic Example

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  environment   = "dev"
  vpc_cidr      = "10.0.0.0/16"
  aws_region    = "us-east-1"
  my_ip_address = "203.0.113.45/32"
  
  public_subnet_cidrs  = ["10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.2.0/24"]
  availability_zones   = ["us-east-1a"]
  
  # Enable NAT instance (FREE)
  enable_nat_instance = true
  nat_instance_type   = "t2.micro"
  
  # Optional features
  enable_flow_logs       = true
  enable_session_manager = true
  
  tags = {
    Project   = "production-platform"
    ManagedBy = "terraform"
  }
}
```

### Multi-AZ Setup (Production)

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  environment = "prod"
  vpc_cidr    = "10.0.0.0/16"
  
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
  
  enable_nat_instance = true
  nat_instance_type   = "t3.small"  # More capacity
  
  tags = {
    Environment = "production"
  }
}
```

---

## 📥 Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name (dev/staging/prod) | `string` | - | ✅ |
| `vpc_cidr` | CIDR block for VPC | `string` | `"10.0.0.0/16"` | ❌ |
| `aws_region` | AWS region | `string` | `"us-east-1"` | ❌ |
| `my_ip_address` | Your IP for SSH access (CIDR) | `string` | - | ✅ |
| `public_subnet_cidrs` | Public subnet CIDR blocks | `list(string)` | `["10.0.1.0/24"]` | ❌ |
| `private_subnet_cidrs` | Private subnet CIDR blocks | `list(string)` | `["10.0.2.0/24"]` | ❌ |
| `availability_zones` | Availability zones to use | `list(string)` | `["us-east-1a"]` | ❌ |
| `enable_nat_instance` | Enable NAT instance | `bool` | `true` | ❌ |
| `nat_instance_type` | NAT instance type | `string` | `"t2.micro"` | ❌ |
| `enable_flow_logs` | Enable VPC Flow Logs | `bool` | `true` | ❌ |
| `enable_session_manager` | Enable Session Manager | `bool` | `true` | ❌ |
| `tags` | Common tags for all resources | `map(string)` | `{}` | ❌ |

---

## 📤 Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `nat_instance_id` | NAT instance ID |
| `nat_instance_public_ip` | NAT instance public IP (Elastic IP) |
| `nat_instance_private_ip` | NAT instance private IP |
| `k3s_security_group_id` | Security group for K3s cluster |
| `s3_vpc_endpoint_id` | S3 VPC endpoint ID |
| `flow_logs_bucket_name` | S3 bucket for VPC Flow Logs |

---

## 🧪 Testing

### 1. Verify NAT Instance

```bash
# Get instance ID
terraform output nat_instance_id

# Access via Session Manager
aws ssm start-session --target $(terraform output -raw nat_instance_id)

# Inside NAT instance:
cat /proc/sys/net/ipv4/ip_forward  # Should output: 1
sudo iptables -t nat -L -n -v      # Should show MASQUERADE
tail -f /var/log/nat-health.log    # Monitor health checks
```

### 2. Test Connectivity from Private Subnet

```bash
# From any instance in private subnet:
curl -I https://google.com         # Should work via NAT
traceroute 8.8.8.8                # Should go through NAT IP
ip route                          # Should show default via NAT
```

### 3. Verify VPC Flow Logs

```bash
# List flow logs
aws ec2 describe-flow-logs

# Check S3 bucket
aws s3 ls s3://$(terraform output -raw flow_logs_bucket_name)/
```

---

## 🛠️ Troubleshooting

### NAT Instance Not Working

**Problem:** Private instances can't reach internet

**Check 1: Source/Dest Check**
```bash
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw nat_instance_id) \
  --query 'Reservations[0].Instances[0].SourceDestCheck'
# Must be: false
```

**Check 2: IP Forwarding**
```bash
# On NAT instance:
cat /proc/sys/net/ipv4/ip_forward  # Must be: 1
```

**Check 3: iptables Rules**
```bash
sudo iptables -t nat -L -n -v | grep MASQUERADE
# Should show NAT rule
```

**Check 4: Route Table**
```bash
# From private instance:
ip route
# Should show: default via <NAT-private-IP>
```

**Check 5: Security Groups**
- NAT SG must allow inbound 80/443 from private subnet
- NAT SG must allow all outbound traffic
- Private instances must have route to NAT

### High NAT Instance CPU

**Solution:** Upgrade instance type
```hcl
nat_instance_type = "t3.small"  # More CPU credits
```

### Connection Tracking Errors

**Check conntrack table:**
```bash
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max
```

**Increase limit if needed:**
```bash
sudo sysctl -w net.netfilter.nf_conntrack_max=131072
```

---

## 🔐 Security Considerations

### ✅ Implemented

- Private subnet isolation (no public IPs)
- Restrictive security groups
- Network ACLs on public subnet
- VPC Flow Logs enabled
- Encrypted EBS volumes
- Session Manager (no SSH keys)
- Rate limiting on NAT forwarding

### ⚠️ Limitations

- **Single Point of Failure:** NAT instance is single-AZ
- **No Auto-Scaling:** Fixed capacity
- **Manual Failover:** Requires intervention if NAT fails
- **Limited Throughput:** Bound by instance network limits

### 🚀 Production Hardening (Next Steps)

For production deployments, we can consider:

1. **Multi-AZ NAT instances** with auto-failover
2. **CloudWatch alarms** for NAT health
3. **Auto-recovery** via EC2 auto-recovery
4. **VPC Endpoints** for AWS services (This will be my next move )
5. **Network Firewall** for advanced filtering
6. **Transit Gateway** for multi-VPC connectivity

---

## 📚 Learn More

### Related Documentation

- [NAT Instance vs NAT Gateway](../../docs/diagrams/Nat_instance.md)
- [Minimal Cost VPC Architecture](../../docs/diagrams/Minimal_cost_vpc.md)
- [Production Architecture Overview](../../docs/diagrams/Production_Architecture_Overview.md)

### AWS Documentation

- [NAT Instances](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)

### Blog Posts (Coming Soon)

- Building a $0 Kubernetes Cluster on AWS
- NAT Instance Deep Dive: Free Alternative to NAT Gateway
- Air-Gapped Kubernetes with VPC Endpoints (Phase 3)

---

## 🎓 Learning Outcomes

By implementing this module, I've learned and familiarized more with:

### Networking Concepts
✅ VPC architecture and CIDR planning  
✅ Public vs private subnets  
✅ Internet Gateway vs NAT functionality  
✅ Routing tables and route propagation  
✅ Network ACLs vs Security Groups  

### Linux Networking
✅ IP forwarding and packet routing  
✅ iptables NAT configuration  
✅ Network troubleshooting (traceroute, tcpdump)  
✅ Connection tracking (conntrack)  

### AWS Services
✅ VPC endpoints (Gateway vs Interface)  
✅ Session Manager (SSM)  
✅ VPC Flow Logs  
✅ IAM roles and instance profiles  

### DevOps Practices
✅ Infrastructure as Code (Terraform)  
✅ Cost optimization strategies  
✅ Security hardening  
✅ Monitoring and observability  

---

## 🚦 What's Next?

### Phase 2: NAT Instance ✅ (Current)
- [x] NAT instance implementation
- [x] Private subnet connectivity
- [x] Health monitoring

### Phase 3: VPC Endpoints + Docker Proxy (Coming)
- [ ] S3-backed Docker registry mirror
- [ ] Zero-egress architecture
- [ ] Air-gapped cluster
- [ ] Automated image synchronization
- [ ] Enterprise-grade security

### Phase 4: Application Deployment
- [ ] Deploy API service
- [ ] Deploy worker service
- [ ] Configure Redis clustering
- [ ] Set up monitoring stack
- [ ] CI/CD pipeline

---

## 📝 License

This module is part of the production-platform project.

---

## 👤 Mizaoui Tasnim 

**Learning Project** - Building production-grade infrastructure on AWS free tier

**Portfolio:** [GitHub Repository](https://github.com/tasnimmizaoui/production-platform)

---

**Cost-Optimized | Production-Ready | Learning-Focused** 🚀
