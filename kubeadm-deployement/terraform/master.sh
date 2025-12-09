#!/bin/bash
# ------------------------------------------------------------------
# MASTER NODE SETUP SCRIPT
# Runs only on the Control Plane node
# ------------------------------------------------------------------

set -e

echo ""
echo "=== MASTER NODE CONFIGURATION ==="
echo "[1/2] Configuring Kubernetes master node..."

CLUSTER_NAME="kubeadm-cluster"
# Check if cluster is already initialized
if [ -f /etc/kubernetes/admin.conf ]; then
        echo "✓ Kubernetes cluster already initialized (skipping kubeadm init)"
        export KUBECONFIG=/etc/kubernetes/admin.conf
else
        echo "Initializing Kubernetes cluster..."

        # A. Create Kubeadm Config for AWS (External Provider)
        cat <<EOF >/tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.29.0
clusterName: ${CLUSTER_NAME}
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
echo "[2/2] Installing cluster components..."

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
                --set args="{--cloud-provider=aws,--configure-cloud-routes=false,--v=2}" \
                --set serviceAccount.create=true \
                --set serviceAccount.name=aws-load-balancer-controller
        echo "✓ AWS Cloud Controller Manager installed"
fi

# F. Install NGINX Ingress Controller
if helm list -n ingress-nginx | grep -q "ingress-nginx"; then
        echo "✓ NGINX Ingress Controller already installed (skipping)"
else
        echo "Installing NGINX Ingress Controller..."
        helm repo add nginx-stable https://helm.nginx.com/stable 2>/dev/null || true
        helm repo update
        helm install ingress-nginx nginx-stable/nginx-ingress --namespace ingress-nginx --create-namespace
        echo "✓ NGINX Ingress Controller installed"
fi

# G. Install EBS CSI Driver (Storage)
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

# H. Save Join Command for easy access
if [ ! -f /home/ubuntu/join-command.sh ]; then
        echo "Generating worker join command..."
        kubeadm token create --print-join-command >/home/ubuntu/join-command.sh
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
