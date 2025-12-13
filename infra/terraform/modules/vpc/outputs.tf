# ============================================
# VPC Outputs
# ============================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.main.arn
}

# ============================================
# Subnet Outputs
# ============================================

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

# ============================================
# Route Table Outputs
# ============================================

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

# ============================================
# Gateway Outputs
# ============================================

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# ============================================
# Security Group Outputs
# ============================================

output "k3s_security_group_id" {
  description = "Security group ID for K3s cluster"
  value       = aws_security_group.k3s.id
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoint.id
}

# ============================================
# VPC Endpoint Outputs
# ============================================

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "s3_prefix_list_id" {
  description = "Prefix list ID for S3 (for security group rules)"
  value       = data.aws_ec2_managed_prefix_list.s3.id
}

# ============================================
# Monitoring Outputs
# ============================================

output "flow_logs_enabled" {
  description = "Whether VPC Flow Logs are enabled"
  value       = var.enable_flow_logs
}

output "flow_logs_bucket_name" {
  description = "S3 bucket name for VPC Flow Logs (if enabled)"
  value       = var.enable_flow_logs ? aws_s3_bucket.flow_logs[0].id : null
}

output "flow_logs_bucket_arn" {
  description = "S3 bucket ARN for VPC Flow Logs (if enabled)"
  value       = var.enable_flow_logs ? aws_s3_bucket.flow_logs[0].arn : null
}

# ============================================
# Metadata Outputs
# ============================================

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}