#!/bin/bash
# ------------------------------------------------------------------
# COMMON SETUP SCRIPT (Kubernetes v1.29 on AWS)
# Runs on both Master and Worker nodes
# ------------------------------------------------------------------

set -e

echo "=== Starting Common Kubernetes Setup ==="

# 1. SET HOSTNAME (CRITICAL: Must match AWS Private DNS)
# We use IMDSv2 to get the metadata safely
echo "[1/5] Setting hostname..."
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
PRIVATE_DNS=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-hostname`
CURRENT_HOSTNAME=$(hostname)

if [ "$CURRENT_HOSTNAME" != "$PRIVATE_DNS" ]; then
    hostnamectl set-hostname $PRIVATE_DNS
    echo "✓ Hostname set to: $PRIVATE_DNS"
else
    echo "✓ Hostname already set to: $PRIVATE_DNS (skipping)"
fi

# 2. SYSTEM PRE-REQUISITES
echo "[2/5] Installing system prerequisites..."
sudo apt-get update -qq

# Check and install required packages only if not present
REQUIRED_PACKAGES="apt-transport-https ca-certificates curl gpg lsb-release"
PACKAGES_TO_INSTALL=""

for pkg in $REQUIRED_PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
    fi
done

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installing missing packages:$PACKAGES_TO_INSTALL"
    sudo apt-get install -y $PACKAGES_TO_INSTALL
else
    echo "✓ All required packages already installed (skipping)"
fi

# Disable Swap (idempotent)
echo "Disabling swap..."
sudo swapoff -a 2>/dev/null || true
if ! grep -q "^#.*swap" /etc/fstab; then
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "✓ Swap disabled in /etc/fstab"
else
    echo "✓ Swap already disabled in /etc/fstab (skipping)"
fi

# Kernel Modules (idempotent)
echo "Configuring kernel modules..."
if [ ! -f /etc/modules-load.d/k8s.conf ]; then
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    echo "✓ Kernel modules configuration created"
else
    echo "✓ Kernel modules configuration already exists (skipping)"
fi

sudo modprobe overlay 2>/dev/null || true
sudo modprobe br_netfilter 2>/dev/null || true

# Network Configuration (Bridging) (idempotent)
echo "Configuring network settings..."
if [ ! -f /etc/sysctl.d/k8s.conf ]; then
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    sudo sysctl --system > /dev/null
    echo "✓ Network configuration applied"
else
    echo "✓ Network configuration already exists (skipping)"
fi

# 3. INSTALL CONTAINERD
echo "[3/5] Installing containerd..."
if ! dpkg -l | grep -q "^ii  containerd.io "; then
    sudo mkdir -p /etc/apt/keyrings
    
    # Only download GPG key if not already present
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "✓ Docker GPG key added"
    fi
    
    # Only add repository if not already present
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        echo "✓ Docker repository added"
    fi
    
    sudo apt-get update -qq
    sudo apt-get install -y containerd.io
    echo "✓ Containerd installed"
else
    echo "✓ Containerd already installed (skipping)"
fi

# Configure Containerd (SystemdCgroup = true is MANDATORY)
echo "Configuring containerd..."
sudo mkdir -p /etc/containerd

if [ ! -f /etc/containerd/config.toml ] || ! grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
    containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
    echo "✓ Containerd configured with SystemdCgroup"
else
    echo "✓ Containerd already configured (skipping)"
fi

# Ensure containerd is running
sudo systemctl enable containerd 2>/dev/null || true
sudo systemctl start containerd 2>/dev/null || true

# 4. INSTALL KUBERNETES TOOLS (v1.29)
echo "[4/5] Installing Kubernetes tools..."
if ! command -v kubeadm &> /dev/null || ! command -v kubelet &> /dev/null || ! command -v kubectl &> /dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    
    # Only download GPG key if not already present
    if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo "✓ Kubernetes GPG key added"
    fi
    
    # Only add repository if not already present
    if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        echo "✓ Kubernetes repository added"
    fi
    
    sudo apt-get update -qq
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    echo "✓ Kubernetes tools installed (kubelet, kubeadm, kubectl)"
else
    echo "✓ Kubernetes tools already installed (skipping)"
    # Ensure they are on hold
    sudo apt-mark hold kubelet kubeadm kubectl 2>/dev/null || true
fi

# 5. INSTALL HELM (Required for AWS Cloud Controller)
echo "[5/5] Installing Helm..."
if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✓ Helm installed"
else
    HELM_VERSION=$(helm version --short 2>/dev/null || echo "unknown")
    echo "✓ Helm already installed: $HELM_VERSION (skipping)"
fi

echo "=== COMMON SETUP COMPLETE ==="
