# Production Platform - AWS Free Tier

> A production-grade platform built on AWS **completely free** using cost-optimization strategies and infrastructure best practices.

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Free%20Tier-orange?logo=amazon-aws)](https://aws.amazon.com/free/)
[![K3s](https://img.shields.io/badge/K3s-Lightweight%20K8s-blue?logo=kubernetes)](https://k3s.io/)
[![Cost](https://img.shields.io/badge/Monthly%20Cost-$0-green)](https://github.com)

---

## 🎯 Project Goals

Build a **real production platform** for learning, demonstrating:

- ✅ **Infrastructure as Code** (Terraform)
- ✅ **Cost Optimization** ($0/month vs $505/year standard AWS)
- ✅ **Kubernetes Orchestration** (K3s cluster)
- ✅ **Networking Best Practices** (VPC, NAT, security groups)
- ✅ **Security Hardening** (private subnets, Session Manager, flow logs)
- ✅ **Microservices Architecture** (Go API, Worker, Redis)
- ✅ **CI/CD Pipeline** (Docker, automated deployments)
- ✅ **Monitoring & Observability** (Prometheus, Grafana, Loki)

**Perfect for:**
- 📚 Learning DevOps/SRE practices
- 💼 Portfolio/resume projects
- 🎓 Interview preparation
- 🚀 Small production workloads

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│ AWS VPC (10.0.0.0/16)                               │
│                                                      │
│  Public Subnet                Private Subnet        │
│  ┌─────────────┐              ┌─────────────┐      │
│  │ NAT Instance│──────────────→│ K3s Master  │      │
│  │ (t2.micro)  │              │ (t3.micro)  │      │
│  └──────┬──────┘              └──────┬──────┘      │
│         │                             │             │
│         │                     ┌───────▼──────┐      │
│         │                     │ K3s Worker   │      │
│         │                     │ (t3.micro)   │      │
│         │                     └──────┬───────┘      │
│         │                            │              │
│         │                            ▼              │
│         │                   ┌────────────────┐      │
│         │                   │ Pods:          │      │
│         │                   │ • API Service  │      │
│         │                   │ • Worker       │      │
│         │                   │ • Redis        │      │
│         │                   └────────────────┘      │
│         ▼                                           │
│   Internet Gateway                                  │
└─────────────────────────────────────────────────────┘
         │
         ▼
    Internet
```

---

## 💰 Cost Breakdown

### Traditional AWS Setup
| Component | Monthly Cost |
|-----------|--------------|
| NAT Gateway | $32.85 |
| Bastion Host (t2.micro) | $8.47 |
| K3s Master (t3.micro) | $7.59 |
| K3s Worker (t3.micro) | $7.59 |
| EBS Storage (40GB) | $4.00 |
| **TOTAL** | **$60.50/month** |

### This Project (Free Tier Optimized)
| Component | Monthly Cost |
|-----------|--------------|
| NAT Instance (t2.micro) | **$0** (free tier) |
| Session Manager | **$0** (no bastion) |
| K3s Master (t3.micro) | **$0** (free tier) |
| K3s Worker (t3.micro) | **$0** (free tier) |
| EBS Storage (30GB) | **$0** (free tier) |
| **TOTAL** | **$0/month** ✅ |

**Annual Savings: $726** 💸

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required tools
terraform >= 1.0
aws-cli >= 2.0
kubectl >= 1.24

# AWS credentials configured
aws configure
```

### Deploy Infrastructure

```bash
# Clone repository
git clone https://github.com/yourusername/production-platform
cd production-platform

# Configure variables
cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
# Edit terraform.tfvars with your IP address

# Get your IP
curl ifconfig.me

# Deploy
cd infra/terraform
terraform init
terraform plan
terraform apply
```

**Deployment time: ~15-20 minutes** ⏱️

### Access Your Cluster

```bash
# Get kubeconfig
terraform output kubeconfig_command | bash > ~/.kube/config

# Verify cluster
kubectl get nodes
kubectl get pods -A

# Access K3s master
aws ssm start-session --target $(terraform output -raw k3s_master_id)
```

---

## 📁 Project Structure

```
production-platform/
├── app/                          # Application code
│   ├── api-service/             # Go REST API
│   ├── worker-service/          # Background workers
│   └── frontend/                # React UI
│
├── infra/                       # Infrastructure as Code
│   └── terraform/
│       ├── main.tf              # Root configuration
│       ├── modules/
│       │   ├── vpc/             # VPC + NAT instance
│       │   └── k3s/             # K3s cluster
│       └── terraform.tfvars     # Your variables
│
├── k8s/                         # Kubernetes manifests
│   ├── base/                    # Base configs
│   │   ├── api/
│   │   ├── worker/
│   │   └── redis/
│   └── overlays/                # Environment overlays
│       ├── dev/
│       └── prod/
│
├── monitoring/                  # Observability stack
│   ├── prometheus/
│   ├── grafana/
│   └── loki/
│
├── ci/                         # CI/CD pipelines
│   └── scripts/
│
├── docs/                       # Documentation
│   └── diagrams/
│
└── scripts/                    # Helper scripts
    ├── deploy.sh
    └── test-deployment.sh
```

---

## 🏗️ Infrastructure Components

### Phase 1: Networking ✅ COMPLETE
- [x] VPC (10.0.0.0/16)
- [x] Public & Private subnets
- [x] Internet Gateway
- [x] NAT Instance (free alternative to NAT Gateway)
- [x] VPC Flow Logs (S3)
- [x] S3 VPC Endpoint
- [x] **Verified:** All connectivity tests passing

### Phase 2: Compute ✅ COMPLETE
- [x] K3s master node (t3.micro)
- [x] K3s worker node (t3.micro)
- [x] Redis (in-cluster pod)
- [x] IAM roles & instance profiles
- [x] Session Manager access
- [x] **Verified:** 2/2 nodes Ready, pods running

### Phase 3: Applications 📋 NEXT
- [ ] Deploy API service to K3s
- [ ] Deploy worker service
- [ ] Configure ingress
- [ ] Test end-to-end workflow

### Phase 4: CI/CD Pipeline 🚀
- [ ] GitHub Actions workflow
- [ ] Automated testing (Go tests)
- [ ] Docker image builds
- [ ] Kind cluster validation
- [ ] Automated deployments

### Phase 5: VPC Endpoints + Docker Proxy (Enterprise) 🎯
- [ ] S3-backed Docker registry mirror
- [ ] Zero-egress network architecture
- [ ] Air-gapped cluster security
- [ ] Automated image synchronization

---

## 🔐 Security Features

- ✅ **Private Subnets** - No public IPs on workloads
- ✅ **NAT Instance** - Controlled egress
- ✅ **Security Groups** - Restrictive firewall rules
- ✅ **Network ACLs** - Additional layer
- ✅ **VPC Flow Logs** - Network monitoring
- ✅ **Session Manager** - No SSH keys needed
- ✅ **Encrypted EBS** - Data at rest encryption
- ✅ **IP Whitelisting** - Access limited to your IP

---

## 📊 Key Innovations

### 1. NAT Instance ($32/month savings)

Instead of AWS NAT Gateway ($32.85/month), we use a t2.micro instance:

```bash
# IP forwarding + iptables
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

**Benefits:**
- $0 cost (free tier)
- Full control & debugging access
- Production-ready for small workloads
- Learning opportunity for NAT mechanics

**Trade-offs:**
- Single point of failure (no HA)
- Manual scaling required
- Limited throughput vs NAT Gateway

**Real Implementation:**
- ✅ Verified working with K3s cluster
- ✅ Internet access from private subnet confirmed
- ✅ Health monitoring configured
- ✅ $394/year savings vs NAT Gateway

[**Read Complete Implementation Guide →**](docs/NAT_Instance_Implementation.md) 

### 2. Session Manager Access ($8/month savings)

No bastion host needed! Access instances via AWS Systems Manager:

```bash
aws ssm start-session --target i-0abc123def456
```

**Benefits:**
- $0 cost
- No SSH keys to manage
- IAM-based authentication
- Session logging

### 3. K3s Lightweight Kubernetes

Full Kubernetes experience with minimal overhead:

- 512MB RAM vs 2GB (standard K8s)
- Single binary installation
- Built-in storage, networking
- Perfect for learning & small workloads

---

## 📚 Documentation

- [NAT Instance Implementation Guide](docs/NAT_Instance_Implementation.md) - Complete NAT setup, troubleshooting, and verification
- [VPC Module README](infra/terraform/modules/vpc/README.md) - Networking architecture and configuration
- [K3s Module README](infra/terraform/modules/k3s/README.md) - Cluster setup and management
- [Production Architecture](docs/diagrams/Production_Architecture_Overview.md) - Full stack overview

---

## 🧪 Testing

```bash
# Verify NAT instance
aws ssm start-session --target $(terraform output -raw nat_instance_id)
cat /proc/sys/net/ipv4/ip_forward  # Should be: 1

# Test K3s cluster
kubectl get nodes
kubectl get pods -A

# Test connectivity from private subnet
aws ssm start-session --target $(terraform output -raw k3s_master_id)
curl -I https://google.com  # Should work via NAT

# Run deployment tests
./scripts/test-deployment.sh
```

---

## 🛠️ Troubleshooting

### NAT Instance Not Working

```bash
# Check source/dest check (must be false)
aws ec2 describe-instances --instance-ids <nat-id> \
  --query 'Reservations[0].Instances[0].SourceDestCheck'

# Check iptables
aws ssm start-session --target <nat-id>
sudo iptables -t nat -L -n -v
```

### K3s Pods Not Starting

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Can't Access Internet from Private Subnet

```bash
# From private instance
ip route  
traceroute 8.8.8.8  # S

# Check NAT instance
aws ssm start-session --target <nat-id>
cat /proc/sys/net/ipv4/ip_forward  # Must be: 1
sudo iptables -t nat -L POSTROUTING -n -v  # Must show MASQUERADE rule
```

[**Complete Troubleshooting Guide →**](docs/NAT_Instance_Implementation.md#troubleshooting-guide)

---

## 🎓 Learning Outcomes

### Terraform Skills
- Module development
- State management
- Dependency management
- Count and conditionals

### AWS Networking
- VPC architecture
- NAT functionality
- Security groups vs NACLs
- VPC endpoints

### Kubernetes
- Cluster setup
- Pod networking
- Service discovery
- Storage management

### Linux Systems
- IP forwarding
- iptables/netfilter
- systemd services
- Shell scripting

### DevOps Practices
- Infrastructure as Code
- Cost optimization
- Security hardening
- Monitoring/observability

---

## 📈 Roadmap

- [x] **Phase 1:** VPC networking with NAT instance
- [x] **Phase 2:** K3s cluster deployment (2 nodes + Redis)
- [ ] **Phase 3:** Application deployment (API + Worker services)
- [ ] **Phase 4:** CI/CD pipeline (GitHub Actions + Kind testing)
- [ ] **Phase 5:** VPC endpoints + Docker proxy (enterprise security)
- [ ] **Phase 6:** Monitoring stack (Prometheus, Grafana, Loki)
- [ ] **Phase 7:** Service mesh (Linkerd)
- [ ] **Phase 8:** Auto-scaling & high availability

**Current Status:** Infrastructure verified and working. Ready for application deployment! 🚀

---

## 🤝 Contributing

This is a learning project, but suggestions are welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📝 Blog Series (Coming Soon)

1. **Building a $0 Kubernetes Cluster on AWS**
2. **NAT Instance vs NAT Gateway: A Cost Analysis**
3. **Air-Gapped Kubernetes with VPC Endpoints**
4. **Monitoring K3s with Free Tools**
5. **Production-Ready Security on a Budget**

---

## 🙏 Acknowledgments

- **K3s** - Lightweight Kubernetes by Rancher
- **Terraform** - Infrastructure as Code by HashiCorp
- **AWS** - Cloud infrastructure
- **Community** - Best practices and inspiration

---

## 📄 License

MIT License - Feel free to use this project for learning and portfolio purposes.

---

## 👤 Author

**Your Name**
- Portfolio: [your-portfolio.com](https://your-portfolio.com)
- GitHub: [@yourusername](https://github.com/yourusername)
- LinkedIn: [Your Name](https://linkedin.com/in/yourprofile)

---

## ⭐ If This Helped You

Give this repo a star ⭐ and share it with others learning DevOps!

**Questions?** Open an issue or reach out on LinkedIn.

---

**Built with ❤️ for learning, optimized for $0 cost, ready for production.**

🚀 Happy Learning!
