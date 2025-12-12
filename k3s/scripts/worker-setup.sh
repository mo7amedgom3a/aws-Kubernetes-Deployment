#!/bin/bash

###############################################################################
# K3s Worker Node Setup Script
# This script installs K3s in agent mode and joins the cluster
# Usage: ./worker-setup.sh <SERVER_PRIVATE_IP> <NODE_TOKEN>
###############################################################################

set -e

# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <SERVER_PRIVATE_IP> <NODE_TOKEN>"
    echo ""
    echo "Example:"
    echo "  $0 10.0.1.100 K10abc123xyz::server:abc123"
    exit 1
fi

SERVER_IP=$1
NODE_TOKEN=$2

echo "========================================="
echo "K3s Worker Node Setup"
echo "========================================="
echo "Server IP: $SERVER_IP"
echo "========================================="

# Update system packages
echo "[1/3] Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Install K3s in agent mode
echo "[2/3] Installing K3s agent and joining cluster..."
curl -sfL https://get.k3s.io | K3S_URL=https://${SERVER_IP}:6443 K3S_TOKEN=${NODE_TOKEN} sh -

# Wait for K3s agent to be ready
echo "[3/3] Waiting for K3s agent to be ready..."
sleep 10
sudo systemctl status k3s-agent --no-pager

echo ""
echo "========================================="
echo "✅ K3s Worker Setup Complete!"
echo "========================================="
echo ""
echo "This node has joined the cluster."
echo "Run 'sudo kubectl get nodes' on the server to verify."
echo ""
