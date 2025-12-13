terraform {
      required_version = "> 1.0"

      backend "s3" {
          bucket = "production-platform-tfstate"
          key    = "terraform.tfstate"
          region = "us-east-1"
          encrypt = true
          # I didn't use versioning just to avoid costs 
      }
}

provider "aws" {
    region = var.aws_region 
    default_tags {
      tags = {
       Project     = "production-platform"
       Environment = var.environment
       ManagedBy   = "terraform"
       FreeTier    = "true"
      }
    }
}
   # Fetching the current AWS account info ( my free tier account ) 
  data "aws_caller_identity" "current" {}
  data "aws_region" "current" {}


# Core Infrastructure
module "vpc" {
  source = "./modules/vpc"
  
  # Required variables
  environment   = var.environment
  vpc_cidr      = "10.0.0.0/16"
  my_ip_address = var.my_ip_address
  aws_region    = var.aws_region  
  
  # Subnet configuration
  public_subnet_cidrs  = ["10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.2.0/24"]
  availability_zones   = ["us-east-1a"]  
  
  # Optional features (already with defaults, but explicit is better)
  enable_flow_logs        = true
  create_bastion_host     = false
  enable_session_manager  = true
  
  # Tags (will be merged with module defaults)
  tags = {
    Project   = "production-platform"
    ManagedBy = "terraform"
  }
}

# Outputs from VPC module (optional but useful)
output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for K3s"
  value       = module.vpc.private_subnet_ids
}

output "k3s_security_group_id" {
  description = "Security group ID for K3s cluster"
  value       = module.vpc.k3s_security_group_id
}


#K3S Cluster 
module "k3s" {
  source = "./modules/k3s"
  environment = var.environment 
  private_subnet_ids = module.vpc.private_subnet_ids 
  k3s_security_group_id  = module.vpc.k3s_security_group_id

  
  # Instance configuration (free tier)
  master_instance_type = "t3.micro"  # 750 hours/month free
  worker_instance_type = "t3.micro"
  worker_count         = 1  # 1 master + 1 worker = within free tier
  
  tags = {
    Project   = "production-platform"
    ManagedBy = "terraform"
  }

}

# K3s Outputs
output "k3s_master_ip" {
  description = "K3s master node private IP"
  value       = module.k3s.master_private_ip
}

output "k3s_kubeconfig_command" {
  description = "Command to retrieve kubeconfig"
  value       = module.k3s.kubeconfig_command
}