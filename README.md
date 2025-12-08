# AWS Kubernetes Cluster with kubeadm

This repository contains Terraform configuration to deploy a self-hosted Kubernetes cluster on AWS using kubeadm.

## Architecture

- **VPC**: Custom VPC with public subnet
- **Master Node**: 1x t3.medium EC2 instance
- **Worker Nodes**: 2x t3.medium EC2 instances
- **IAM Roles**: Separate roles for master and worker nodes with necessary AWS permissions
- **Security Groups**: Configured for Kubernetes communication

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. SSH key pair created in AWS (default: `kubeadm-key`)

## Deployment Steps

### 1. Create SSH Key Pair

```bash
# Create SSH key pair in AWS
aws ec2 create-key-pair --key-name kubeadm-key --query 'KeyMaterial' --output text > ~/.ssh/kubeadm-key.pem
chmod 400 ~/.ssh/kubeadm-key.pem
```

### 2. Deploy Infrastructure

```bash
cd kubeadm-deployement/terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

### 3. Initialize Kubernetes Cluster

After infrastructure deployment, SSH to the master node:

```bash
# Get master node IP from Terraform output
terraform output master_node_public_ip

# SSH to master node
ssh -i ~/.ssh/kubeadm-key.pem ubuntu@<master-ip>
```

On the master node, initialize the cluster:

```bash
# Initialize Kubernetes cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=<master-private-ip>

# Configure kubectl for regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 4. Install CNI Plugin

Install Flannel CNI plugin:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### 5. Join Worker Nodes

Get the join command from master node:

```bash
# On master node
kubeadm token create --print-join-command
```

SSH to each worker node and run the join command:

```bash
# SSH to worker nodes
ssh -i ~/.ssh/kubeadm-key.pem ubuntu@<worker-ip>

# Run the join command (replace with actual command from master)
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### 6. Verify Cluster

On the master node:

```bash
# Check node status
kubectl get nodes

# Check all pods
kubectl get pods --all-namespaces
```

## IAM Permissions

The setup includes comprehensive IAM roles with permissions for:

### Master Node Role
- EC2: Instance management, security groups, volumes
- ELB: Load balancer management
- Auto Scaling: Cluster autoscaler support
- ECR: Container registry access
- CloudWatch: Logging and monitoring
- Route53: External DNS support
- IAM: Service account management

### Worker Node Role
- EC2: Basic instance operations
- ECR: Container registry access
- CloudWatch: Logging and monitoring

## Security Groups

- **Master SG**: Ports 22 (SSH), 6443 (API), 2379-2380 (etcd), 10250 (kubelet), 10257-10259 (controllers)
- **Worker SG**: Ports 22 (SSH), 10250 (kubelet), 30000-32767 (NodePort), communication with master
- **Load Balancer SG**: Ports 80 (HTTP), 443 (HTTPS)

## Customization

Edit `variables.tf` to customize:
- AWS region
- Instance types
- Cluster name
- CIDR blocks
- Key pair name

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

## Next Steps

After cluster deployment, consider installing:
- AWS Load Balancer Controller
- External DNS
- Cluster Autoscaler
- Metrics Server
- Ingress Controller

## Troubleshooting

1. **Nodes not joining**: Check security groups allow communication between nodes
2. **Pods stuck in Pending**: Verify CNI plugin is installed
3. **Image pull errors**: Ensure ECR permissions are correct
4. **Load balancer issues**: Install AWS Load Balancer Controller

## Files Structure

```
├── kuberenetes-setup.sh          # Node setup script
└── kubeadm-deployement/
    └── terraform/
        ├── main.tf               # Provider configuration
        ├── variables.tf          # Input variables
        ├── vpc.tf               # VPC and networking
        ├── security_groups.tf    # Security groups
        ├── iam.tf               # IAM roles and policies
        ├── ec2.tf               # EC2 instances
        └── outputs.tf           # Output values
```
