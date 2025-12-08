#!/bin/bash
# ------------------------------------------------------------------
# MASTER & WORKER SETUP SCRIPT (Kubernetes v1.29 on AWS)
# Enhanced with idempotency checks
# ------------------------------------------------------------------

set -e

echo "=== Starting Kubernetes Setup Script ==="

# 1. SET HOSTNAME (CRITICAL: Must match AWS Private DNS)
# We use IMDSv2 to get the metadata safely
echo "[1/7] Setting hostname..."
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
echo "[2/7] Installing system prerequisites..."
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
echo "[3/7] Installing containerd..."
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
echo "[4/7] Installing Kubernetes tools..."
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
echo "[5/7] Installing Helm..."
if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✓ Helm installed"
else
    HELM_VERSION=$(helm version --short 2>/dev/null || echo "unknown")
    echo "✓ Helm already installed: $HELM_VERSION (skipping)"
fi

# ------------------------------------------------------------------
# LOGIC BRANCH: MASTER VS WORKER
# ------------------------------------------------------------------
# Detect if we are on the Control Plane by checking the Terraform variable or Tag
# (This simple check assumes you pass 'master' as the first argument to the script or handle it in Terraform)
NODE_TYPE=${node_type:-"worker"} # Default to worker if not set

if [ "$NODE_TYPE" = "master" ]; then
    echo ""
    echo "=== MASTER NODE CONFIGURATION ==="
    echo "[6/7] Configuring Kubernetes master node..."
    
    # Check if cluster is already initialized
    if [ -f /etc/kubernetes/admin.conf ]; then
        echo "✓ Kubernetes cluster already initialized (skipping kubeadm init)"
        export KUBECONFIG=/etc/kubernetes/admin.conf
    else
        echo "Initializing Kubernetes cluster..."
        
        # A. Create Kubeadm Config for AWS (External Provider)
        cat <<EOF > /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.29.0
clusterName: my-k8s-cluster
networking:
  podSubnet: 192.168.0.0/16
apiServer:
  extraArgs:
    cloud-provider: "external"
controllerManager:
  extraArgs:
    cloud-provider: "external"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

        # B. Initialize Cluster
        sudo kubeadm init --config /tmp/kubeadm-config.yaml --ignore-preflight-errors=NumCPU
        echo "✓ Kubernetes cluster initialized"
        
        # C. Setup Kubeconfig for Root & Ubuntu User
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        
        # Allow 'ubuntu' user to run kubectl
        mkdir -p /home/ubuntu/.kube
        sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
        sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
        echo "✓ Kubeconfig configured for root and ubuntu users"
        
        # Export KUBECONFIG for the rest of the script
        export KUBECONFIG=/etc/kubernetes/admin.conf
    fi

    # Ensure KUBECONFIG is set for subsequent operations
    export KUBECONFIG=/etc/kubernetes/admin.conf

    # D. Install Networking (Calico)
    echo "[7/7] Installing cluster components..."
    
    # Check if Calico operator is already installed
    if kubectl get deployment tigera-operator -n tigera-operator &>/dev/null; then
        echo "✓ Calico operator already installed (skipping)"
    else
        echo "Installing Calico Operator..."
        kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
        echo "✓ Calico operator installed"
    fi
    
    # Wait for CRDs to be established
    echo "Waiting for Calico CRDs to be established..."
    kubectl wait --for condition=established --timeout=60s crd/installations.operator.tigera.io 2>/dev/null || true
    kubectl wait --for condition=established --timeout=60s crd/apiservers.operator.tigera.io 2>/dev/null || true
    
    # Check if Calico custom resources are already applied (check both installation and apiserver)
    if kubectl get installation default &>/dev/null 2>&1 && kubectl get apiserver default &>/dev/null 2>&1; then
        echo "✓ Calico custom resources already applied (skipping)"
    else
        echo "Applying Calico Custom Resources..."
        # Use 'apply' instead of 'create' to make it idempotent
        kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml
        echo "✓ Calico custom resources applied"
    fi

    # E. Install AWS Cloud Controller Manager
    # Check if AWS Cloud Controller is already installed
    if helm list -n kube-system | grep -q "aws-cloud-controller-manager"; then
        echo "✓ AWS Cloud Controller Manager already installed (skipping)"
    else
        echo "Installing AWS Cloud Controller Manager..."
        helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws 2>/dev/null || true
        helm repo update
        # We explicitly set cloud-provider=aws to AVOID the crash we saw earlier
        helm upgrade --install aws-cloud-controller-manager aws-cloud-controller-manager/aws-cloud-controller-manager \
          --namespace kube-system \
          --set args="{--cloud-provider=aws,--configure-cloud-routes=false,--v=2}"
        echo "✓ AWS Cloud Controller Manager installed"
    fi

    # F. Install EBS CSI Driver (Storage)
    # Check if EBS CSI Driver is already installed
    if kubectl get deployment ebs-csi-controller -n kube-system &>/dev/null; then
        echo "✓ EBS CSI Driver already installed (skipping)"
    else
        echo "Installing EBS CSI Driver..."
        kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
        echo "✓ EBS CSI Driver installed"
    fi
    
    # Create Default Storage Class (gp3)
    if kubectl get storageclass gp3 &>/dev/null; then
        echo "✓ Storage class 'gp3' already exists (skipping)"
    else
        echo "Creating default storage class (gp3)..."
        cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
        echo "✓ Storage class 'gp3' created"
    fi

    # G. Save Join Command for easy access
    if [ ! -f /home/ubuntu/join-command.sh ]; then
        echo "Generating worker join command..."
        kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
        chmod +x /home/ubuntu/join-command.sh
        echo "✓ Join command saved to /home/ubuntu/join-command.sh"
    else
        echo "✓ Join command already exists at /home/ubuntu/join-command.sh"
        echo "  (To regenerate, delete the file and run this script again)"
    fi
    
    echo ""
    echo "=== MASTER SETUP COMPLETE ==="
    echo "✓ Cluster is ready!"
    echo "✓ Join command available at: /home/ubuntu/join-command.sh"
    echo ""

else
    echo ""
    echo "=== WORKER NODE SETUP COMPLETE ==="
    echo "✓ Worker node is ready to join the cluster"
    echo ""
    echo "Next steps:"
    echo "1. Wait for Master to finish initializing."
    echo "2. Log into Master and run 'cat ~/join-command.sh'."
    echo "3. Copy that command and run it here with 'sudo'."
    echo ""
fi