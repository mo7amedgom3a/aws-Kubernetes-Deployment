# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.k3s_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.k3s_public_subnet.id
}

output "security_group_id" {
  description = "ID of the K3s security group"
  value       = aws_security_group.k3s_sg.id
}

# Server Node Outputs
output "server_public_ip" {
  description = "Public IP of the K3s server node"
  value       = aws_instance.k3s_server.public_ip
}

output "server_private_ip" {
  description = "Private IP of the K3s server node"
  value       = aws_instance.k3s_server.private_ip
}

# Worker Node 1 Outputs
output "worker_1_public_ip" {
  description = "Public IP of K3s worker node 1"
  value       = aws_instance.k3s_worker_1.public_ip
}

output "worker_1_private_ip" {
  description = "Private IP of K3s worker node 1"
  value       = aws_instance.k3s_worker_1.private_ip
}

# Worker Node 2 Outputs
output "worker_2_public_ip" {
  description = "Public IP of K3s worker node 2"
  value       = aws_instance.k3s_worker_2.public_ip
}

output "worker_2_private_ip" {
  description = "Private IP of K3s worker node 2"
  value       = aws_instance.k3s_worker_2.private_ip
}

# SSH Connection Commands
output "ssh_server" {
  description = "SSH command for server node"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.k3s_server.public_ip}"
}

output "ssh_worker_1" {
  description = "SSH command for worker node 1"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.k3s_worker_1.public_ip}"
}

output "ssh_worker_2" {
  description = "SSH command for worker node 2"
  value       = "ssh -i <your-key.pem> ubuntu@${aws_instance.k3s_worker_2.public_ip}"
}
