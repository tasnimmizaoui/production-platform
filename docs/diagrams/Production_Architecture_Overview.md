# Phase 4: AWS Infrastructure Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                              │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                    │   │
│  │                                                         │   │
│  │  ┌──────────────────┐      ┌──────────────────┐         │   │
│  │  │  Public Subnet   │      │  Public Subnet   │         │   │
│  │  │   (us-east-1a)   │      │   (us-east-1b)   │         │   │
│  │  │  10.0.1.0/24     │      │  10.0.2.0/24     │         │   │
│  │  │                  │      │                  │         │   │
│  │  │  ┌────────────┐  │      │  ┌────────────┐  │         │   │
│  │  │  │    NAT     │  │      │  │    NAT     │  │         │   │
│  │  │  │  Gateway   │  │      │  │  Gateway   │  │         │   │
│  │  │  └────────────┘  │      │  └────────────┘  │         │   │
│  │  └──────────────────┘      └──────────────────┘         │   │
│  │           │                        │                    │   │
│  │  ┌────────▼─────────┐      ┌───────▼──────────┐         │   │
│  │  │  Private Subnet  │      │  Private Subnet  │         │   │
│  │  │   (us-east-1a)   │      │   (us-east-1b)   │         │   │
│  │  │  10.0.10.0/24    │      │  10.0.20.0/24    │         │   │
│  │  │                  │      │                  │         │   │
│  │  │  ┌────────────┐  │      │  ┌────────────┐  │         │   │
│  │  │  │ EKS Nodes  │  │      │  │ EKS Nodes  │  │         │   │
│  │  │  │  (t3.small)│  │      │  │  (t3.small)│  │         │   │
│  │  │  └────────────┘  │      │  └────────────┘  │         │   │
│  │  │  ┌────────────┐  │      │  ┌────────────┐  │         │   │
│  │  │  │   Redis    │  │      │  │  API Pods  │  │         │   │
│  │  │  │   Pods     │  │      │  │ Worker Pods│  │         │   │
│  │  │  └────────────┘  │      │  └────────────┘  │         │   │
│  │  └──────────────────┘      └──────────────────┘         │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │        Application Load Balancer (ALB)                  │   │
│  │        - HTTPS Termination (Let's Encrypt)              │   │
│  │        - Routes to EKS Ingress                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
└──────────────────────────────┼──────────────────────────────────┘
                               │
                        Internet Gateway
                               │
                        ┌──────▼──────┐
                        │   Route53   │
                        │  (Optional) │
                        └─────────────┘
                               │
                        api.yourdomain.com
```

## Key Components

### 1. **VPC (Virtual Private Cloud)**
- Isolated network in AWS
- CIDR: 10.0.0.0/16 (65,536 IPs)
- Multi-AZ for high availability

### 2. **Subnets**
**Public Subnets:**
- NAT Gateways for private subnet internet access
- Load Balancers
- Bastion hosts (if needed)

**Private Subnets:**
- EKS worker nodes
- Application pods
- No direct internet access (security)

### 3. **NAT Gateway**
- Allows private subnet internet access
- For pulling Docker images
- For external API calls
- **Cost:** ~$32/month per NAT

### 4. **EKS Cluster**
- Managed Kubernetes control plane
- AWS handles master nodes
- We manage worker nodes
- **Cost:** $73/month for control plane

### 5. **Worker Nodes**
- t3.small instances (2 vCPU, 2GB RAM)
- Auto-scaling group (2-4 nodes)
- **Cost:** ~$15/month per node

### 6. **Application Load Balancer**
- Layer 7 load balancing
- TLS termination
- Path-based routing
- **Cost:** ~$16/month + data transfer

## Cost Breakdown (Monthly)

| Component | Configuration | Cost |
|-----------|--------------|------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 Instances | 2x t3.small | $30 |
| NAT Gateway | 2x (HA) | $64 |
| ALB | 1 load balancer | $16 |
| EBS Volumes | 50GB | $5 |
| Data Transfer | ~100GB | $9 |
| **Total** | | **~$197/month** |

## Cost Optimization Strategies

### 1. **Single NAT Gateway** (saves $32/month)
```hcl
# Use one NAT instead of two
# Trade-off: No HA for NAT
single_nat_gateway = true
```

### 2. **Spot Instances** (saves 60-70%)
```hcl
# Use spot instances for non-critical workloads
capacity_type = "SPOT"
# Cost: ~$6/month per node
```

### 3. **Fargate** (pay per pod)
```hcl
# No EC2 management
# Pay only for running pods
# Good for variable workloads
```

### 4. **Free Tier Usage**
```hcl
# First 12 months:
# - 750 hours t2.micro EC2
# - 50GB EBS storage
# - 15GB data transfer
```

## Optimized Budget Setup (~$90/month)

| Component | Configuration | Cost |
|-----------|--------------|------|
| EKS Control Plane | 1 cluster | $73 |
| EC2 Instances | 2x t3.small (spot) | $12 |
| NAT Gateway | 1x (single AZ) | $32 |
| ALB | 1 load balancer | $16 |
| **Total** | | **~$133/month** |

## Further Optimization (~$73/month)

**Development/Learning Setup:**
- Skip NAT Gateway (use public subnets temporarily)
- Use 1 t3.micro instance (free tier eligible)
- Skip ALB (use NodePort or port-forward)

**Production Minimum:**
- Keep EKS control plane: $73
- Use Fargate: pay-per-pod
- Use AWS Certificate Manager (free)

## Security Groups

```
┌──────────────────────────────────────────┐
│  ALB Security Group                      │
│  - Inbound: 443 (HTTPS) from 0.0.0.0/0  │
│  - Outbound: All to EKS nodes            │
└──────────────────────────────────────────┘
                   │
┌──────────────────▼───────────────────────┐
│  EKS Node Security Group                 │
│  - Inbound: ALB security group           │
│  - Inbound: 443 from control plane       │
│  - Outbound: All                         │
└──────────────────────────────────────────┘
```

## IAM Roles

```
EKS Cluster Role
├─ AmazonEKSClusterPolicy
└─ AmazonEKSVPCResourceController

EKS Node Role
├─ AmazonEKSWorkerNodePolicy
├─ AmazonEKS_CNI_Policy
├─ AmazonEC2ContainerRegistryReadOnly
└─ CloudWatchAgentServerPolicy (optional)

ALB Ingress Controller Role (IRSA)
├─ AWSLoadBalancerControllerIAMPolicy
└─ Trust relationship with EKS OIDC
```

## High Availability

**Multi-AZ Deployment:**
- Subnets in 2+ availability zones
- EKS nodes distributed across AZs
- ALB spans multiple AZs
- Automatic failover

**Failure Scenarios:**

| Failure | Impact | Recovery |
|---------|--------|----------|
| Single pod dies | None | K8s restarts |
| Single node fails | Temporary capacity loss | ASG launches new node |
| Single AZ fails | 50% capacity | Traffic routes to other AZ |
| NAT Gateway fails | Private subnet offline | Switch to backup NAT |

## Terraform State Management

```
S3 Bucket (Backend)
├─ Versioning enabled
├─ Encryption at rest
└─ Access logging

DynamoDB Table (Locking)
├─ terraform-locks
└─ Prevents concurrent modifications
```

## Deployment Flow

```
1. terraform init
   └─ Initialize providers
   └─ Configure S3 backend

2. terraform plan
   └─ Preview changes
   └─ Estimate costs

3. terraform apply
   └─ Create VPC
   └─ Create EKS cluster (15-20 min)
   └─ Create node group (5 min)
   └─ Configure kubectl access

4. kubectl apply
   └─ Deploy applications
   └─ Configure ingress
   └─ Setup monitoring
```

## Monitoring & Observability

**AWS CloudWatch:**
- EKS control plane logs
- Node metrics
- Container insights

**Prometheus + Grafana:**
- Custom application metrics
- Already configured from Phase 2

**Cost Explorer:**
- Daily cost tracking
- Budget alerts
- Resource optimization

## Next Steps After Deployment

1. **Setup kubectl access**
   ```bash
   aws eks update-kubeconfig --name production-cluster --region us-east-1
   ```

2. **Install AWS Load Balancer Controller**
   ```bash
   helm install aws-load-balancer-controller eks/aws-load-balancer-controller
   ```

3. **Deploy applications**
   ```bash
   kubectl apply -f k8s/base/
   ```

4. **Configure DNS** (optional)
   ```bash
   # Point domain to ALB DNS name
   ```

5. **Setup TLS with cert-manager**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

## Migration Path

**From Minikube to EKS:**

| Component | Change Required | Difficulty |
|-----------|----------------|------------|
| Deployments | None | Easy |
| Services | None | Easy |
| ConfigMaps | None | Easy |
| Ingress | Update annotations | Medium |
| Storage | Change StorageClass | Medium |
| Secrets | Use AWS Secrets Manager | Medium |

Most of your K8s manifests work without changes!