output "master_instance_id" {
  description = "K3s master node instance ID"
  value       = aws_instance.k3s_master.id
}

output "master_private_ip" {
  description = "K3s master node private IP"
  value       = aws_instance.k3s_master.private_ip
}

output "worker_instance_ids" {
  description = "K3s worker node instance IDs"
  value       = aws_instance.k3s_worker[*].id
}

output "worker_private_ips" {
  description = "K3s worker node private IPs"
  value       = aws_instance.k3s_worker[*].private_ip
}

output "cluster_token_ssm_parameter" {
  description = "SSM parameter name containing cluster token"
  value       = aws_ssm_parameter.k3s_token.name
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig from master node"
  value       = "aws ssm start-session --target ${aws_instance.k3s_master.id} --document-name AWS-StartInteractiveCommand --parameters command='sudo cat /etc/rancher/k3s/k3s.yaml'"
}