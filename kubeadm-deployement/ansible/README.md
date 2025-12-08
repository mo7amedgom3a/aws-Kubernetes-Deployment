# Ansible Kubernetes Cluster Setup

This directory contains Ansible playbooks and configuration files to automate the deployment of a Kubernetes cluster using kubeadm.

## 📁 Files Structure

```
ansible/
├── inventory.ini          # Ansible inventory with master and worker nodes
├── playbook.yml           # Main playbook for Kubernetes setup
├── requirements.txt       # Python/Ansible dependencies
├── setup-cluster.sh       # Automated setup script
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Python 3.6+** installed
2. **SSH key** (`aws_my_key.pem`) in your home directory
3. **Ansible** installed (will be installed automatically if missing)

### Automated Setup

```bash
cd ansible
./setup-cluster.sh
```

### Manual Setup

1. **Install Ansible**:
   ```bash
   pip3 install -r requirements.txt
   ```

2. **Test connectivity**:
   ```bash
   ansible all -i inventory.ini -m ping
   ```

3. **Run the playbook**:
   ```bash
   ansible-playbook -i inventory.ini playbook.yml -v
   ```

## 📋 What the Playbook Does

### Phase 1: System Preparation (All Nodes)
- Updates system packages
- Disables swap (required by Kubernetes)
- Loads required kernel modules (`overlay`, `br_netfilter`)
- Configures sysctl parameters for networking
- Installs Docker repository and containerd
- Installs Kubernetes components (kubelet, kubeadm, kubectl)
- Configures kubelet with systemd cgroup driver

### Phase 2: Master Node Initialization
- Initializes Kubernetes cluster with kubeadm
- Configures kubectl for the ubuntu user
- Installs Flannel CNI plugin
- Generates join command for worker nodes

### Phase 3: Worker Node Joining
- Retrieves join command from master node
- Joins worker nodes to the cluster
- Verifies successful joining

### Phase 4: Cluster Verification
- Waits for all nodes to be ready
- Displays cluster status and information

## 🔧 Configuration

### Inventory Configuration

The `inventory.ini` file contains:

```ini
[master]
18.204.42.144

[workers]
3.239.208.41
13.218.111.213

[k8s_cluster:children]
master
workers

[all:vars]
ansible_ssh_private_key_file=~/aws_my_key.pem
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

### Playbook Variables

Key variables in `playbook.yml`:

- `kube_version`: "1.28" (Kubernetes version)
- `pod_network_cidr`: "10.244.0.0/16" (Flannel network)
- `service_cidr`: "10.96.0.0/12" (Kubernetes services)

## 🎯 Expected Results

After successful execution, you should have:

1. **Master Node**: Running Kubernetes control plane
2. **Worker Nodes**: Joined to the cluster
3. **CNI Plugin**: Flannel installed and configured
4. **All Nodes**: Ready and schedulable

## 🔍 Verification Commands

SSH to the master node and run:

```bash
# Check node status
kubectl get nodes -o wide

# Check all pods
kubectl get pods --all-namespaces

# Check cluster info
kubectl cluster-info

# Check system pods
kubectl get pods -n kube-system
```

## 🛠️ Troubleshooting

### Common Issues

1. **SSH Connection Failed**:
   - Verify SSH key path: `~/aws_my_key.pem`
   - Check security groups allow SSH (port 22)
   - Ensure instances are running

2. **Package Installation Failed**:
   - Check internet connectivity
   - Verify Ubuntu repositories are accessible
   - Check for sufficient disk space

3. **Cluster Initialization Failed**:
   - Check master node has sufficient resources (2+ CPU, 2+ GB RAM)
   - Verify network connectivity between nodes
   - Check security group rules

4. **Worker Join Failed**:
   - Verify join command is correct
   - Check network connectivity between master and workers
   - Ensure worker nodes have sufficient resources

### Debug Commands

```bash
# Run playbook with verbose output
ansible-playbook -i inventory.ini playbook.yml -vvv

# Test specific hosts
ansible master -i inventory.ini -m ping
ansible workers -i inventory.ini -m ping

# Run specific tasks
ansible-playbook -i inventory.ini playbook.yml --tags "install"

# Check Ansible version
ansible --version
```

## 📊 Monitoring

After cluster setup, monitor with:

```bash
# Watch node status
watch kubectl get nodes

# Watch pods
watch kubectl get pods --all-namespaces

# Check system resources
kubectl top nodes
kubectl top pods --all-namespaces
```

## 🔄 Cleanup

To destroy the cluster:

```bash
# From master node
sudo kubeadm reset --force

# From worker nodes
sudo kubeadm reset --force

# Then destroy infrastructure with Terraform
cd ../terraform
terraform destroy
```

## 📚 Next Steps

After successful cluster deployment:

1. **Install AWS Load Balancer Controller**
2. **Configure External DNS**
3. **Set up Cluster Autoscaler**
4. **Install Metrics Server**
5. **Deploy monitoring stack (Prometheus/Grafana)**
6. **Configure RBAC and security policies**

## 🤝 Support

If you encounter issues:

1. Check the Ansible logs for specific error messages
2. Verify all prerequisites are met
3. Ensure network connectivity between all nodes
4. Check AWS security group configurations
5. Review Terraform outputs for correct IP addresses
