# SECURITY GROUPS (Zero cost - critical for security

# K3s cluster security group
resource "aws_security_group" "k3s" {
  name_prefix = "${var.environment}-k3s-"
  vpc_id      = aws_vpc.main.id
  

  # Allow SSH from my IP directly (temporary for setup)
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }
  
  # K3s API from my IP
  ingress {
    description = "K3s API from my IP"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }
  
  # Allow all within VPC (for pod communication)
  ingress {
    description = "Internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  
  # Limited egress - only what's needed
  egress {
    description = "HTTPS to internet (for pulls)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description = "VPC endpoints access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.s3.id]
  }
  
  tags = merge(var.tags, {
    Name = "${var.environment}-k3s-sg"
  })
}


# VPC endpoint security group
resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "${var.environment}-endpoint-"
  vpc_id      = aws_vpc.main.id
  
  # HTTPS from K3s and Redis
  ingress {
    description = "HTTPS from K3s"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  # Allow responses
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(var.tags, {
    Name = "${var.environment}-endpoint-sg"
  })
}
#=====================================
# Security Group for NAT Instance
#=====================================
resource "aws_security_group" "nat" {
  name_prefix = "${var.environment}-nat-"
  description = "Security group for NAT instance"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP from private subnets
  ingress {
    description = "HTTP from private subnet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  # Allow HTTPS from private subnets
  ingress {
    description = "HTTPS from private subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  # Allow SSH from your IP (for troubleshooting)
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-nat-sg"
  })
}