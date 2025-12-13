# Secure VPC with NAT Gateway alternative for $0 cost
# 1. Main VPC with DNS and monitoring
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  
  # Critical security settings (FREE)
  enable_dns_support     = true
  enable_dns_hostnames   = true
  
  tags = merge(var.tags, {
    Name = "${var.environment}-vpc"
  })
}


# 2. PUBLIC SUBNETS (for bastion, NAT proxy)
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  # Public subnets for internet-facing resources
  map_public_ip_on_launch = true
  
  tags = merge(var.tags, {
    Name = "${var.environment}-public-${count.index + 1}"
    Tier = "public"
  })
}

# 3. PRIVATE SUBNETS (for K3s  - NO NAT GATEWAY COST)
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  # Private subnets - no auto public IP
  map_public_ip_on_launch = false
  
  tags = merge(var.tags, {
    Name = "${var.environment}-private-${count.index + 1}"
    Tier = "private"
  })
}

# 4. ISOLATED SUBNETS (for databases, future use)
/*
resource "aws_subnet" "isolated" {
  count = var.create_isolated_subnets ? length(var.isolated_subnet_cidrs) : 0
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.isolated_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  map_public_ip_on_launch = false
  
  tags = merge(var.tags, {
    Name = "${var.environment}-isolated-${count.index + 1}"
    Tier = "isolated"
  })
}*/


# 5. INTERNET GATEWAY (FREE - only pay for data transfer)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(var.tags, {
    Name = "${var.environment}-igw"
  })
}

# 6. NAT GATEWAY ALTERNATIVE: VPC Endpoints (FREE for S3, ECR)
# Instead of $32/month NAT Gateway, i will use VPC endpoints
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  
  # Route table association
  route_table_ids = [
    aws_route_table.private.id,
    # aws_route_table.isolated.id
  ]
  
  # S3 endpoint is FREE
  tags = merge(var.tags, {
    Name = "${var.environment}-s3-endpoint"
  })
}

# I'm deleting this for now since i will use DOCKERHUB to pull images and eliminate the cost of using 
# This expensive endpoint  
/*
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
  # Place in private subnets
  subnet_ids = aws_subnet.private[*].id
  
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  
  # Interface endpoints have small cost but we'll manage it
  tags = merge(var.tags, {
    Name = "${var.environment}-ecr-api-endpoint"
  })
}*/ 

# 7. ROUTE TABLES with security-focused routing
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(var.tags, {
    Name = "${var.environment}-public-rt"
  })
}

# Private Route Table (NO NAT - uses VPC endpoints)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Internal routes only
  
  tags = merge(var.tags, {
    Name = "${var.environment}-private-rt"
    Description = "No internet access - uses VPC endpoints"
  })
}

# Isolated Route Table (most restrictive)
/*
resource "aws_route_table" "isolated" {
  count = var.create_isolated_subnets ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  # No routes at all - completely isolated
  # Future: peering connections if needed
  
  tags = merge(var.tags, {
    Name = "${var.environment}-isolated-rt"
  })
}*/

# 8. ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

/*
resource "aws_route_table_association" "isolated" {
  count = var.create_isolated_subnets ? length(aws_subnet.isolated) : 0
  
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated[0].id
}*/

# 9. SECURITY GROUPS (Zero cost - critical for security)


/* I eleminated the bastion resource already 
# Bastion host security group
resource "aws_security_group" "bastion" {
  name_prefix = "${var.environment}-bastion-"
  vpc_id      = aws_vpc.main.id
  
  # SSH only from your IP
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]  # My IP
  }
  
  # Allow bastion to reach private subnets
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR only
  }
  
  tags = merge(var.tags, {
    Name = "${var.environment}-bastion-sg"
  })
}
*/


# K3s cluster security group
resource "aws_security_group" "k3s" {
  name_prefix = "${var.environment}-k3s-"
  vpc_id      = aws_vpc.main.id
  
  # REMOVE THIS - bastion doesn't exist anymore
  # ingress {
  #   description     = "SSH from bastion"
  #   from_port       = 22
  #   to_port         = 22
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.bastion.id]
  # }
  
  # REMOVE THIS TOO
  # ingress {
  #   description     = "K3s API from bastion"
  #   from_port       = 6443
  #   to_port         = 6443
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.bastion.id]
  # }
  
  # Allow SSH from your IP directly (temporary for setup)
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }
  
  # K3s API from your IP
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

# 10. NETWORK ACLs (FREE - additional layer)
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id
  
  # Allow ephemeral ports back in
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  
  # Allow HTTP/HTTPS in
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
   
   # ADD EGRESS RULES (NACLs are stateless!)
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Default deny (implicit)
  
  tags = merge(var.tags, {
    Name = "${var.environment}-public-nacl"
  })
}

# 11. VPC FLOW LOGS to S3 (FREE storage under 5GB)
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.flow_logs[0].arn  # Add [0] index
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  
  tags = merge(var.tags, {
    Name = "${var.environment}-vpc-flow-logs"
  })
}

# S3 bucket for flow logs (FREE under 5GB)
resource "aws_s3_bucket" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  bucket = "${var.environment}-${data.aws_caller_identity.current.account_id}-flow-logs"
  
  tags = merge(var.tags, {
    Name = "Flow logs bucket"
  })
}

# Block public access (security)
resource "aws_s3_bucket_public_access_block" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy to allow VPC Flow Logs to write
resource "aws_s3_bucket_policy" "flow_logs" {
  count  = var.enable_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.flow_logs[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.flow_logs[0].arn
      }
    ]
  })
}

# 12. BASTION HOST (t2.nano - $3/month or use Session Manager)
# Option A: EC2 bastion (cheap)
/*
resource "aws_instance" "bastion" {
  count = var.create_bastion_host ? 1 : 0
  
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.nano"  # ~$3/month, or use free t2.micro if not using for K3s
  
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.ssh_key_name
  
  # Minimal storage
  root_block_device {
    volume_size = 8
    volume_type = "gp2"
  }
  
  # User data to harden bastion
  user_data = <<-EOF
    #!/bin/bash
    # Harden bastion host
    yum update -y
    # Disable password authentication
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
    # Install AWS Session Manager plugin for free access
    yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
  EOF
  
  tags = merge(var.tags, {
    Name = "${var.environment}-bastion"
  })
}*/

# Option B: I will use AWS Session Manager (FREE )
resource "aws_iam_role" "session_manager" {
  count = var.enable_session_manager ? 1 : 0
  
  name = "${var.environment}-session-manager"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "session_manager" {
  count = var.enable_session_manager ? 1 : 0
  
  role       = aws_iam_role.session_manager[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 13. DATA SOURCES
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get S3 prefix list for VPC endpoint routing
data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}