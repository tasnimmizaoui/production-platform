

    ┌────────────────────────────────────────┐
    │ VPC (10.0.0.0/16)                      │
    │                                        │
    │  Public Subnet (10.0.1.0/24)           │
    │  └── Internet Gateway (FREE)           │
    │                                        │
    │  Private Subnet (10.0.2.0/24)          │
    │  └── K3s Cluster                       │
    │      ├── API Service                   │
    │      ├── Worker Service                │
    │      └── Redis                         │
    │                                        │
    │  Infrastructure:                       │
    │  ├── S3 VPC Endpoint (FREE)            │
    │  ├── Flow Logs → S3 (FREE < 5GB)       │
    │  └── Session Manager (FREE)            │
    └────────────────────────────────────────┘

Monthly Cost: $0


## Deployment Options 
Considering the fact that our K3s master node need internet access there are 3 Options : 

###  Cost-Optimized (NAT Instance)
```bash
terraform apply -var="deployment_mode=nat_instance"
```
**Use case:** Production on budget, startups

###  Enterprise (VPC Endpoints + Proxy)
```bash
terraform apply -var="deployment_mode=enterprise"
```
**Use case:** Security-critical applications, compliance

## Architecture Comparison
[Include the diagrams above]

## Blog Posts
- "Building a $0 Kubernetes Cluster on AWS"
- "NAT Gateway vs NAT Instance: Cost Analysis"
- "**Air-Gapped Kubernetes: Zero-Egress Architecture**" ⭐