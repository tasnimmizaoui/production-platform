# ============================================
# VPC Outputs
# ============================================

output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs for K3s"
  value       = module.vpc.private_subnet_ids
}

/* ============================================
# NAT Instance Outputs
 -> Why ?
    Especially in our case we need to manage our Nat instance 
        Access NAT instance for troubleshooting
        Monitor NAT health
        Check iptables rules
============================================*/

output "nat_instance_id" {
  description = "NAT instance ID (for Session Manager access)"
  value       = module.vpc.nat_instance_id
}

output "nat_instance_public_ip" {
  description = "NAT instance public IP (Elastic IP)"
  value       = module.vpc.nat_instance_public_ip
}

output "nat_instance_private_ip" {
  description = "NAT instance private IP"
  value       = module.vpc.nat_instance_private_ip
}

# ============================================
# Security Group Outputs
# ============================================

output "k3s_security_group_id" {
  description = "Security group ID for K3s cluster"
  value       = module.vpc.k3s_security_group_id
}

# ============================================
# K3s Cluster Outputs
# ============================================

output "k3s_master_id" {
  description = "K3s master node instance ID"
  value       = module.k3s.master_instance_id
}

output "k3s_master_private_ip" {
  description = "K3s master node private IP"
  value       = module.k3s.master_private_ip
}

output "k3s_worker_ids" {
  description = "K3s worker node instance IDs"
  value       = module.k3s.worker_instance_ids
}

output "k3s_worker_private_ips" {
  description = "K3s worker node private IPs"
  value       = module.k3s.worker_private_ips
}

# ============================================
# Access Commands
# ============================================

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from master node"
  value       = module.k3s.kubeconfig_command
}

output "nat_instance_session_command" {
  description = "Command to access NAT instance via Session Manager"
  value       = "aws ssm start-session --target ${module.vpc.nat_instance_id}"
}

output "k3s_master_session_command" {
  description = "Command to access K3s master via Session Manager"
  value       = "aws ssm start-session --target ${module.k3s.master_instance_id}"
}

# ============================================
# Deployment Summary
# ============================================

output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    environment = var.environment
    region      = var.aws_region
    vpc_id      = module.vpc.vpc_id
    
    nat_enabled = module.vpc.nat_instance_id != null ? "Yes (${module.vpc.nat_instance_public_ip})" : "No"
    
    k3s_cluster = {
      master = module.k3s.master_private_ip
      workers = module.k3s.worker_private_ips
    }
    
    cost_estimate = "~$0/month (within free tier)"
  }
}


