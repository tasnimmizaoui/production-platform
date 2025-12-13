variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for K3s nodes"
  type        = list(string)
}

variable "k3s_security_group_id" {
  description = "Security group ID for K3s cluster"
  type        = string
}

variable "master_instance_type" {
  description = "Instance type for K3s master node"
  type        = string
  default     = "t3.micro"  # Free tier eligible (750 hours/month)
  
  validation {
    condition     = can(regex("^t[23]\\.(micro|small|medium)$", var.master_instance_type))
    error_message = "Use free tier eligible instances: t2.micro, t3.micro, t3.small"
  }
}

variable "worker_instance_type" {
  description = "Instance type for K3s worker nodes"
  type        = string
  default     = "t3.micro"
}

variable "worker_count" {
  description = "Number of worker nodes (0-2 for free tier)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.worker_count >= 0 && var.worker_count <= 2
    error_message = "Keep worker_count between 0-2 for free tier (750 hours total/month)."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}