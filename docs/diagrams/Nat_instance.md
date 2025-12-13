# Building a $0 NAT Instance on AWS - Free Tier Alternative to NAT Gateway

## The Problem
AWS NAT Gateway costs $32/month + data transfer fees. For learning and small projects, this is expensive.

## The Solution
Use a t2.micro EC2 instance as a NAT device. Cost: $0 within free tier.

## Architecture

    ┌─────────────────────────────────────────────────────┐
    │ VPC (10.0.0.0/16)                                   │
    │                                                      │
    │  ┌──────────────────────────────────────┐          │
    │  │ Public Subnet (10.0.1.0/24)         │          │
    │  │                                      │          │
    │  │  ┌─────────────────┐                │          │
    │  │  │ NAT Instance    │ ← Elastic IP   │          │
    │  │  │ (t2.micro)      │    (Public)    │          │
    │  │  └────────┬────────┘                │          │
    │  │           │                          │          │
    │  └───────────┼──────────────────────────┘          │
    │              │ (IP forwarding + iptables)          │
    │              ↓                                      │
    │  ┌──────────────────────────────────────┐          │
    │  │ Private Subnet (10.0.2.0/24)        │          │
    │  │                                      │          │
    │  │  ┌─────────────┐  ┌─────────────┐  │          │
    │  │  │ K3s Master  │  │ K3s Worker  │  │          │
    │  │  │ (private)   │  │ (private)   │  │          │
    │  │  └─────────────┘  └─────────────┘  │          │
    │  │                                      │          │
    │  └──────────────────────────────────────┘          │
    │                                                      │
    │  Route: 0.0.0.0/0 → NAT Instance ENI                │
    └─────────────────────────────────────────────────────┘
                        │
                        ↓
                Internet

## Cost Comparison

| Component | NAT Gateway | NAT Instance |
|-----------|-------------|--------------|
| Hourly Rate | $0.045 | $0.0116 (t2.micro) |
| Monthly (730h) | **$32.85** | **$8.47** |
| Free Tier | ❌ No | ✅ Yes (750h/month) |
| **My Cost** | **$32.85/mo** | **$0/mo** |

## Implementation

### 1. NAT Instance Configuration

```bash
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Configure iptables
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

[Include your code snippets]

### 2. Terraform Module

[Include key terraform resources]

### 3. Testing

```bash
# From private subnet instance
curl https://api.github.com
# Success!
```

## Limitations

- Single point of failure (no HA)
- Performance limited to instance type
- Manual failover required
- Need monitoring

## When to Use

✅ Development environments
✅ Small projects
✅ Cost-sensitive workloads
❌ Production critical apps
❌ High throughput needs

## Monitoring

[Include health check script]

## Next Steps

This setup saves $32/month while maintaining security. For production, consider:
1. Multi-AZ NAT instances with auto-failover
2. Managed NAT Gateway for mission-critical apps
3. VPC Endpoints for AWS services (coming in Part 3!)

## Full Code

[Link to GitHub repo]