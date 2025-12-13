# latest Amzon Linux 2023 AMI 
data "aws_ami"  "amazon_linux_2023" {
    most_recent = true 
    owners = [ "amazon" ]
    filter {
      name = "name"
      values = ["al2023-ami-*-x86_64"] 
     }
    filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

# IAM role for the k3s Nodes (Session Manager Access  )
resource "aws_iam_role" "k3s_node" {
  name_prefix = "${var.environment}-k3s-node-"

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
    Name = "${var.environment}-k3s-node-role"
  })
}

# Attach Session Manager Policy ( for ssh-less access )
resource "aws_iam_role_policy_attachment" "k3s_ssm" {
    role = aws_iam_role.k3s_node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile : 
resource "aws_iam_instance_profile" "k3s_node" {
     name_prefix = "${var.environment}-k3s-node"
     role = aws_iam_role.k3s_node.name 
     
     tags = var.tags
} 

# K3s Master Node ( server )
resource "aws_instance" "k3s_master" {
    ami = data.aws_ami.amazon_linux_2023.id 
    instance_type =  var.master_instance_type 
    subnet_id = var.private_subnet_ids [0]
    vpc_security_group_ids = [ var.k3s_security_group_id ]
    iam_instance_profile = aws_iam_instance_profile.k3s_node.name

    # Use this for production (creates EBS volume)
  root_block_device {
    volume_size           = 30  # GB (Amazon Linux 2023 minimum, free tier: 30GB)
    volume_type           = "gp3"  # Cheaper than gp2
    delete_on_termination = true
    encrypted             = true
  }
  user_data = base64encode(templatefile("${path.module}/user-data-master.sh", {
    cluster_token = random_password.k3s_token.result
    environment   = var.environment
  }))
  
  tags = merge(var.tags, {
    Name = "${var.environment}-k3s-master"
    Role = "k3s-master"
  })

  lifecycle {
    ignore_changes = [ami]  # Don't recreate on AMI updates
  }
}

# K3s Worker node 
resource "aws_instance" "k3s_worker" {
  count                  = var.worker_count
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [var.k3s_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.k3s_node.name

  root_block_device {
    volume_size           = 30  # Amazon Linux 2023 minimum
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data-worker.sh", {
    cluster_token      = random_password.k3s_token.result
    master_private_ip  = aws_instance.k3s_master.private_ip
    environment        = var.environment
  }))

  tags = merge(var.tags, {
    Name = "${var.environment}-k3s-worker-${count.index + 1}"
    Role = "k3s-worker"
  })

  depends_on = [aws_instance.k3s_master]

  lifecycle {
    ignore_changes = [ami]
  }
  
}

# K3s Cluster Token (secure)
resource "random_password" "k3s_token" {
  length  = 32
  special = true
}

# Store token in SSM parameter Store (encrypted and free) 
resource "aws_ssm_parameter" "k3s_token" {
name = "/${var.environment}/k3s/cluster-token"
description = "K3s cluster join token"
type = "SecureString"
value = random_password.k3s_token.result
tags = merge(var.tags, {
    Name = "${var.environment}-k3s-token"
  })
  
}

# Stor Kubeconfig location 
resource "aws_ssm_parameter" "k3_kubeconfig" {
    name = "/${var.environment}/k3s/kubeconfig-location"
    description = "Location of k3s kubeconfig on master node "
    type = "String"
    value = "/etc/rancher/k3s/k3s.yaml"

    tags = merge(var.tags, {
    Name = "${var.environment}-k3s-kubeconfig"
  })
  
}