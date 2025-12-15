# NAT Instance Connectivity Troubleshooting Guide

**Date:** December 15, 2025  
**Issue:** NAT instance and K3s master instances unable to reach internet (100% packet loss to 8.8.8.8)  
**Resolution Time:** ~2 hours  
**Root Cause:** Incomplete security group and Network ACL configurations

---

## Problem Summary

After running `terraform apply`, both the NAT instance and K3s master instances in private subnet lost internet connectivity:

```bash
# From NAT instance
ping -c 3 8.8.8.8
# Result: 100% packet loss

# From K3s master
ping -c 3 8.8.8.8
# Result: 100% packet loss
```

---

## Troubleshooting Process (Step by Step)

### Phase 1: NAT Instance Internal Configuration

#### ✅ Checked iptables MASQUERADE Rule
```bash
sudo iptables -t nat -L -n -v
```
**Result:** Rule present and active
- 3635 packets, 230K bytes processed
- MASQUERADE rule for 10.0.0.0/16 → 0.0.0.0/0

#### ✅ Checked IP Forwarding
```bash
cat /proc/sys/net/ipv4/ip_forward
```
**Result:** Enabled (value = 1)

#### ✅ Checked FORWARD Chain
```bash
sudo iptables -L FORWARD -n -v
```
**Result:** Correct rules in place
- 43946 packets (8.46MB) from VPC forwarded
- ESTABLISHED,RELATED state tracking active

### Phase 2: AWS Infrastructure Validation

#### ✅ Verified Elastic IP Association
```bash
aws ec2 describe-addresses --allocation-ids eipalloc-xxx
```
**Result:** EIP correctly attached to NAT instance
- Public IP: 34.194.148.96
- Associated with: i-067d29cd1c782a330

#### ✅ Verified Internet Gateway
```bash
aws ec2 describe-internet-gateways --internet-gateway-ids igw-xxx
```
**Result:** IGW attached and available
- State: available
- VPC: vpc-02249de3688b9d22b

#### ✅ Verified Route Tables
```bash
aws ec2 describe-route-tables
```
**Result:**
- Public subnet: 0.0.0.0/0 → IGW (correct)
- Private subnet: 0.0.0.0/0 → NAT instance ENI (correct)

### Phase 3: Security Layer Analysis

#### ❌ ISSUE #1: NAT Security Group Ingress Rules Missing

**Command:**
```bash
aws ec2 describe-security-groups --filters "Name=group-name,Values=*nat*" \
  --query 'SecurityGroups[0].IpPermissions' --output json
```

**Found:** Only these ingress rules:
- TCP 22 from my IP (SSH)
- TCP 80 from 10.0.2.0/24 (HTTP from private subnet)
- TCP 443 from 10.0.2.0/24 (HTTPS from private subnet)

**Missing:**
- ❌ ICMP from internet (for ping responses)
- ❌ TCP ephemeral ports 1024-65535 from internet (for return traffic)
- ❌ UDP ephemeral ports 1024-65535 from internet (for DNS responses)

**Why this matters:**
Security groups are stateful for connections INITIATED from inside to outside. However, when the NAT instance itself initiates a connection (like `ping 8.8.8.8` from the NAT), the return packets need explicit ingress rules.

#### ❌ ISSUE #2: Network ACL Ingress Rules Missing

**Command:**
```bash
aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=subnet-0f4c2222aea7b401a" \
  --query 'NetworkAcls[0].Entries' --output json
```

**Found:** Ingress rules only for:
- TCP 1024-65535 (rule 100)
- TCP 80 (rule 110)
- TCP 443 (rule 120)

**Missing:**
- ❌ ICMP (for ping responses)
- ❌ UDP 1024-65535 (for DNS and other UDP responses)

**Why this matters:**
Network ACLs are **stateless** - they don't track connection state. You must explicitly allow BOTH outbound request AND inbound response, even for the same connection.

#### ❌ ISSUE #3: K3s Security Group Egress Too Restrictive

**Command:**
```bash
aws ec2 describe-security-groups --group-ids sg-04004ff3b62ca0f5a \
  --query 'SecurityGroups[0].IpPermissionsEgress' --output json
```

**Found:** Only TCP 443 allowed outbound

**Missing:**
- ❌ ICMP (for ping)
- ❌ UDP 53 (for DNS queries)
- ❌ TCP 80 (for HTTP package downloads)

---

## Solutions Implemented

### Fix #1: NAT Security Group - Added Ingress Rules

**File:** `infra/terraform/modules/vpc/security-groups.tf`

```terraform
# Allow ICMP (ping) responses from internet
ingress {
  description = "ICMP from internet"
  from_port   = -1
  to_port     = -1
  protocol    = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow return traffic on ephemeral ports (for NAT's own connections)
ingress {
  description = "Return traffic from internet"
  from_port   = 1024
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow return traffic on ephemeral ports UDP
ingress {
  description = "Return traffic from internet (UDP)"
  from_port   = 1024
  to_port     = 65535
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**Applied with:**
```bash
terraform apply -auto-approve
```

**Verification:**
```bash
# From NAT instance
ping -c 3 8.8.8.8
# Result: SUCCESS! 3 packets transmitted, 3 received, 0% packet loss
```

### Fix #2: Public Subnet Network ACL - Added Ingress Rules

**File:** `infra/terraform/modules/vpc/main.tf`

```terraform
# Allow ICMP (ping responses)
ingress {
  protocol   = "icmp"
  rule_no    = 130
  action     = "allow"
  cidr_block = "0.0.0.0/0"
  from_port  = 0
  to_port    = 0
  icmp_type  = -1
  icmp_code  = -1
}

# Allow UDP ephemeral ports (for DNS responses, etc)
ingress {
  protocol   = "udp"
  rule_no    = 140
  action     = "allow"
  cidr_block = "0.0.0.0/0"
  from_port  = 1024
  to_port    = 65535
}
```

**Applied with:**
```bash
terraform apply -auto-approve
```

### Fix #3: K3s Security Group - Added Egress Rules

**File:** `infra/terraform/modules/vpc/security-groups.tf`

```terraform
# Allow HTTP for package updates
egress {
  description = "HTTP to internet (for package updates)"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow DNS queries
egress {
  description = "DNS queries"
  from_port   = 53
  to_port     = 53
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Allow ICMP for diagnostics
egress {
  description = "ICMP for ping and diagnostics"
  from_port   = -1
  to_port     = -1
  protocol    = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**Applied with:**
```bash
terraform apply -auto-approve
```

**Verification:**
```bash
# From K3s master
ping -c 3 8.8.8.8
# Result: SUCCESS! 3 packets transmitted, 3 received, 0% packet loss
```

---

## Why It Appeared to Work Before

### The Infrastructure State Confusion

**Timeline:**

1. **Initial Deployment (Day 1):**
   - Infrastructure created with NAT at `10.0.1.129`
   - Instance ID: `i-0e713307c7af25b9e`
   - Connectivity worked (possibly due to default rules or different config)

2. **Rebuild (Day 2):**
   - Ran `terraform destroy`
   - Ran `terraform apply` → Created NEW infrastructure
   - New NAT at `10.0.1.176`
   - New Instance ID: `i-067d29cd1c782a330`
   - **Terminal sessions still connected to OLD instance!**

3. **The Discovery:**
   ```bash
   # Checking EIP association
   aws ec2 describe-addresses --allocation-ids eipalloc-xxx
   
   # Found: EIP associated with instance i-0850ce04a30be1994
   # But we were troubleshooting: i-0e713307c7af25b9e (OLD!)
   ```

4. **Root Cause Realization:**
   - Old NAT instance lost its EIP when new infrastructure was created
   - K3s master routes pointed to old NAT IP (didn't update)
   - Security group rules were incomplete from the start
   - Just exposed by the rebuild

### What Actually Changed

| Component | Before | After Terraform Apply | Issue |
|-----------|--------|----------------------|-------|
| NAT Instance ID | i-0e713307c7af25b9e | i-067d29cd1c782a330 | Different instance |
| NAT Private IP | 10.0.1.129 | 10.0.1.176 | Routes outdated |
| EIP Association | Old NAT | New NAT | Old NAT lost internet |
| Security Groups | Incomplete | Still incomplete | Exposed by rebuild |

---

## Key Lessons Learned

### 1. Security Groups vs Network ACLs

**Security Groups (Stateful):**
- Automatically allow return traffic for INITIATED connections
- BUT: If the instance ITSELF initiates traffic, ingress rules needed for responses
- Example: NAT forwarding traffic (stateful ✅), but NAT's own ping (needs ingress ❌)

**Network ACLs (Stateless):**
- MUST explicitly allow both directions
- No connection tracking
- Need rules for:
  - Outbound requests (ephemeral source ports → destination port)
  - Inbound responses (source port → ephemeral destination ports)

### 2. NAT Instance Requirements Checklist

For a functioning NAT instance, you need:

- [x] EC2 instance with source/destination check disabled
- [x] Elastic IP attached
- [x] IP forwarding enabled: `net.ipv4.ip_forward = 1`
- [x] iptables MASQUERADE rule: `iptables -t nat -A POSTROUTING -s <VPC_CIDR> -j MASQUERADE`
- [x] iptables FORWARD rules allowing VPC traffic
- [x] Security group EGRESS: Allow all outbound
- [x] **Security group INGRESS: Allow return traffic from internet** ← This was  missing at first
- [x] Public subnet route: 0.0.0.0/0 → Internet Gateway
- [x] Private subnet route: 0.0.0.0/0 → NAT instance ENI
- [x] **Public subnet NACL: Allow ICMP and UDP return traffic** ← This was  missing at first

### 3. AWS Networking Layers (Order of Evaluation)

```
                    OUTBOUND REQUEST
                    ────────────────→

Instance → Security Group → Network ACL → Internet Gateway → Internet
         (stateful)         (stateless)

                    INBOUND RESPONSE
                    ←────────────────

Internet → Internet Gateway → Network ACL → Security Group → Instance
                              (stateless)    (stateful)
```

**For NACL:** Both arrows need explicit rules  
**For Security Group:** Outbound arrow creates automatic return path (for that connection only)

### 4. Infrastructure State Management

**Best Practices After facing Some issues :**

1. Always verify current resource IDs after `terraform apply`:
   ```bash
   terraform output
   ```

2. Close old SSM sessions and reconnect to new instances :
 This is mainly beacause of the issues faced while manipulating different terminals and after destorying and applying over and over 
   ```bash
   aws ssm start-session --target $(terraform output -raw nat_instance_id)
   ```

3. Use terraform outputs instead of hardcoded IDs:
   ```bash
   # ❌ Bad
   aws ec2 describe-instances --instance-ids i-0e713307c7af25b9e
   
   # ✅ Good
   aws ec2 describe-instances --instance-ids $(terraform output -raw nat_instance_id)
   ```

4. When debugging, confirm you're looking at CURRENT resources:
   ```bash
   # Check if instance exists
   aws ec2 describe-instances --instance-ids <id> --query 'Reservations[0].Instances[0].State.Name'
   ```

---

## Verification Commands

After applying fixes, verify connectivity:

### From NAT Instance
```bash
# Basic connectivity
ping -c 3 8.8.8.8

# DNS resolution
nslookup google.com

# HTTP request
curl -I https://www.google.com

# Check health status
sudo /usr/local/bin/nat-health-check.sh
```

### From K3s Master
```bash
# Basic connectivity
ping -c 3 8.8.8.8

# DNS resolution
nslookup google.com

# Package manager (needs HTTP + HTTPS)
sudo dnf check-update

# Container image pull test
sudo crictl pull nginx:latest
```

### AWS CLI Verification
```bash
# Verify current infrastructure
terraform output

# Check NAT security group rules
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw nat_security_group_id) \
  --query 'SecurityGroups[0].{Ingress:IpPermissions,Egress:IpPermissionsEgress}'

# Check K3s security group rules
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw k3s_security_group_id) \
  --query 'SecurityGroups[0].{Ingress:IpPermissions,Egress:IpPermissionsEgress}'

# Check Network ACL rules
aws ec2 describe-network-acls \
  --filters "Name=association.subnet-id,Values=$(terraform output -raw public_subnet_ids | jq -r '.[0]')" \
  --query 'NetworkAcls[0].Entries'
```

---

## Production Recommendations

### Security Hardening

While we opened ingress for troubleshooting, we shoul consider these production improvements:

1. **Limit ICMP Types:**
   ```terraform
   ingress {
     description = "ICMP echo reply only"
     from_port   = 0  # Echo reply
     to_port     = 0
     protocol    = "icmp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ```

2. **Monitor NAT Traffic:**
   - Enable VPC Flow Logs (already enabled)
   - Set up CloudWatch alarms for unusual traffic patterns
   - Monitor connection tracking table size

3. **Use NAT Gateway for Production:**
   - Managed service (no security group management)
   - Better scaling and availability
   - Higher cost (~$32/month)

### Automation

1. **Add Connectivity Tests to CI/CD:**
   ```yaml
   # GitHub Actions example
   - name: Test NAT Connectivity
     run: |
       NAT_ID=$(terraform output -raw nat_instance_id)
       aws ssm send-command \
         --instance-ids $NAT_ID \
         --document-name "AWS-RunShellScript" \
         --parameters 'commands=["ping -c 3 8.8.8.8"]'
   ```

2. **Automated Health Checks:**
   - NAT instance already has `/usr/local/bin/nat-health-check.sh`
   - Runs every 5 minutes via systemd timer
   - Outputs JSON status to `/tmp/nat-status.json`

---

## Cost Analysis

**Total Changes:** $0 additional cost

- Security Group rules: Free
- Network ACL rules: Free
- No new resources added
- Infrastructure remains within AWS Free Tier

**Breakdown:**
- t2.micro instances: Free Tier eligible (750 hours/month)
- Elastic IP: Free when attached to running instance
- Data transfer: First 100GB/month free
- VPC components: Free

---

## Conclusion

The connectivity issues were caused by incomplete security group and Network ACL configurations that only became apparent after infrastructure rebuild. The fixes ensure:

✅ NAT instance can access internet for its own operations  
✅ Return traffic from internet can reach NAT instance  
✅ K3s instances can perform all necessary operations (ping, DNS, package updates)  
✅ Infrastructure is properly documented for future deployments

**Time to resolution:** ~1.5 hours  
**Downtime:** None (greenfield deployment)  
**Lessons learned:** Always test ALL networking layers after infrastructure changes
