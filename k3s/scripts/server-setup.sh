#!/bin/bash

###############################################################################
# K3s Server Node Setup Script
# This script installs and configures K3s in server mode
###############################################################################

set -e

echo "========================================="
echo "K3s Server Node Setup"
echo "========================================="

# Update system packages
echo "[1/5] Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Install K3s in server mode
echo "[2/5] Installing K3s server..."
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "[3/5] Waiting for K3s to be ready..."
sleep 10
sudo systemctl status k3s --no-pager

# Display node token (needed for workers)
echo ""
echo "========================================="
echo "[4/5] K3s Node Token (save this!):"
echo "========================================="
sudo cat /var/lib/rancher/k3s/server/node-token
echo ""

# Display private IP
echo "========================================="
echo "[5/5] Server Private IP:"
echo "========================================="
hostname -I | awk '{print $1}'
echo ""

# Show cluster status
echo "========================================="
echo "Cluster Status:"
echo "========================================="
sudo kubectl get nodes
echo ""

echo "========================================="
echo "✅ K3s Server Setup Complete!"
echo "========================================="
echo ""
echo "Next Steps:"
echo "1. Copy the NODE TOKEN above"
echo "2. Copy the PRIVATE IP above"
echo "3. Run worker-setup.sh on worker nodes with these values"
echo ""
