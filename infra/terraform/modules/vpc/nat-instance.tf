data "aws_ami" "nat_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# IAM Role for NAT Instance (Session Manager access)
resource "aws_iam_role" "nat" {
  name_prefix = "${var.environment}-nat-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-nat-role"
  })
}

# Attach Session Manager policy
resource "aws_iam_role_policy_attachment" "nat_ssm" {
  role       = aws_iam_role.nat.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "nat" {
  name_prefix = "${var.environment}-nat-"
  role        = aws_iam_role.nat.name

  tags = var.tags
}

# NAT Instance
resource "aws_instance" "nat" {
  count = var.enable_nat_instance ? 1 : 0

  ami                    = data.aws_ami.nat_ami.id
  instance_type          = var.nat_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nat.id]
  iam_instance_profile   = aws_iam_instance_profile.nat.name
  
  # CRITICAL: Disable source/destination check for NAT to work
  source_dest_check = false

  # Bootstrap script to configure NAT
  user_data = base64encode(templatefile("${path.module}/nat-user-data.sh", {
    environment = var.environment
  }))

  # Root volume configuration
  root_block_device {
    volume_size           = 30  # Amazon Linux 2023 minimum (free tier: 30GB)
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-nat-instance"
    Role = "nat"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP for NAT Instance (optional but recommended)
resource "aws_eip" "nat" {
  count = var.enable_nat_instance ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.nat[0].id

  tags = merge(var.tags, {
    Name = "${var.environment}-nat-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route to NAT Instance from Private Subnet
resource "aws_route" "private_nat" {
  count = var.enable_nat_instance ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id

  depends_on = [aws_instance.nat]
}