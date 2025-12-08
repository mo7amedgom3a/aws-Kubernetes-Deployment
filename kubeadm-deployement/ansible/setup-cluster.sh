#!/bin/bash
# Ansible Kubernetes Cluster Setup Script

set -e

echo "🚀 Starting Kubernetes Cluster Setup with Ansible..."

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is not installed. Installing..."
    pip3 install -r requirements.txt
fi

# Check if inventory file exists
if [ ! -f "inventory.ini" ]; then
    echo "❌ inventory.ini not found!"
    exit 1
fi

# Test connectivity to all hosts
echo "🔍 Testing connectivity to all hosts..."
ansible all -i inventory.ini -m ping

if [ $? -eq 0 ]; then
    echo "✅ All hosts are reachable!"
else
    echo "❌ Some hosts are not reachable. Please check your inventory and SSH keys."
    exit 1
fi

# Run the Kubernetes setup playbook
echo "🏗️ Running Kubernetes setup playbook..."
ansible-playbook -i inventory.ini playbook.yml -v

if [ $? -eq 0 ]; then
    echo "🎉 Kubernetes cluster setup completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. SSH to master node: ssh -i ~/.ssh/aws_my_key.pem ubuntu@18.204.42.144"
    echo "2. Check cluster status: kubectl get nodes"
    echo "3. Check all pods: kubectl get pods --all-namespaces"
    echo ""
    echo "🔧 Useful commands:"
    echo "- View cluster info: kubectl cluster-info"
    echo "- Get nodes: kubectl get nodes -o wide"
    echo "- Get pods: kubectl get pods --all-namespaces"
else
    echo "❌ Playbook execution failed. Please check the logs above."
    exit 1
fi
