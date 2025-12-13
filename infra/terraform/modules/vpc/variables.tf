# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for VPC endpoints"
  type        = string
  default     = "us-east-1"
}

# Subnet Configuration
variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (bastion, NAT proxy)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  
  validation {
    condition     = length(var.public_subnet_cidrs) > 0
    error_message = "At least one public subnet is required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (K3s cluster with Redis as pod)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
  
  validation {
    condition     = length(var.private_subnet_cidrs) > 0
    error_message = "At least one private subnet is required."
  }
}

variable "isolated_subnet_cidrs" {
  description = "CIDR blocks for isolated subnets (databases, future use)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "create_isolated_subnets" {
  description = "Whether to create isolated subnets"
  type        = bool
  default     = false
}

# Security Configuration
variable "my_ip_address" {
  description = "Your IP address for SSH access to bastion (format: x.x.x.x/32)"
  type        = string
  
  validation {
    condition     = can(cidrhost(var.my_ip_address, 0))
    error_message = "Must be a valid IP address in CIDR notation (e.g., 1.2.3.4/32)."
  }
}

# Bastion Configuration
variable "create_bastion_host" {
  description = "Whether to create an EC2 bastion host (~$3/month)"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "SSH key pair name for bastion host"
  type        = string
  default     = ""
}

variable "enable_session_manager" {
  description = "Enable AWS Session Manager for bastion access (FREE alternative)"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
    description = "Enables Flow logs to S3 : our cheapest choice now "
    type = bool 
    default = true 
  
}

# Tagging
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "ProductionPlatform"
  }
}

variable "enable_nat_instance" {
    description = "Defines weather we rae using the NAT inntance or not "
    type = bool
    default = true
}
variable "nat_instance_type" {
    description = "Our Nat instanec Type "
    type = string  
    default = "t2.micro"
    validation {
    condition     = can(regex("^t[23]\\.(micro|small)$", var.nat_instance_type))
    error_message = "Use free tier eligible: t2.micro or t3.micro"
  }
}