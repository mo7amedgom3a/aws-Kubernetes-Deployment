output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.k8s_vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "control_plane_public_ip" {
  description = "Public IP address of the control plane node"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP address of the control plane node"
  value       = aws_instance.control_plane.private_ip
}

output "worker_nodes_public_ips" {
  description = "Public IP addresses of the worker nodes"
  value       = aws_instance.worker[*].public_ip
}

output "worker_nodes_private_ips" {
  description = "Private IP addresses of the worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "master_security_group_id" {
  description = "ID of the master node security group"
  value       = aws_security_group.k8s_master_sg.id
}

output "worker_security_group_id" {
  description = "ID of the worker nodes security group"
  value       = aws_security_group.k8s_worker_sg.id
}

output "control_plane_iam_role_arn" {
  description = "ARN of the control plane node IAM role"
  value       = aws_iam_role.control_plane.arn
}

output "worker_iam_role_arn" {
  description = "ARN of the worker nodes IAM role"
  value       = aws_iam_role.worker.arn
}

output "ssh_connection_command" {
  description = "SSH command to connect to the control plane node"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.control_plane.public_ip}"
}

output "cluster_info" {
  description = "Cluster information for kubeadm initialization"
  value = {
    control_plane_ip = aws_instance.control_plane.private_ip
    worker_ips       = aws_instance.worker[*].private_ip
    cluster_name     = var.cluster_name
  }
}

# Network Load Balancer Outputs
output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.k8s_nlb.dns_name
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.k8s_nlb.arn
}

output "api_target_group_arn" {
  description = "ARN of the API server target group"
  value       = aws_lb_target_group.k8s_api.arn
}

output "http_target_group_arn" {
  description = "ARN of the HTTP application target group"
  value       = aws_lb_target_group.k8s_apps_http.arn
}

output "https_target_group_arn" {
  description = "ARN of the HTTPS application target group"
  value       = aws_lb_target_group.k8s_apps_https.arn
}

output "kubernetes_api_endpoint" {
  description = "Kubernetes API endpoint via Load Balancer"
  value       = "https://${aws_lb.k8s_nlb.dns_name}:6443"
}
