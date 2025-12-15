# Secure VPC with NAT Gateway alternative for $0 cost
# Main VPC with DNS and monitoring
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  
  # Critical security settings (FREE)
  enable_dns_support     = true
  enable_dns_hostnames   = true
  
  tags = merge(var.tags, {
    Name = "${var.environment}-vpc"
  })
}


# PUBLIC SUBNETS 
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

# PRIVATE SUBNETS
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

# INTERNET GATEWAY (FREE - only pay for data transfer)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(var.tags, {
    Name = "${var.environment}-igw"
  })
}

# NETWORK ACLs (FREE - additional layer)
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

# VPC FLOW LOGS to S3 (FREE storage under 5GB)
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

# AWS Session Manager  ( More secure and FREE )
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

# DATA SOURCES
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