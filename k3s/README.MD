K3s Cluster on AWS EC2
📖 Project Overview

This project sets up a lightweight Kubernetes cluster using K3s on AWS EC2 instances. The architecture consists of one Master node and two Worker nodes residing in public subnets. It demonstrates how to utilize K3s-native features like Traefik Ingress and Klipper LoadBalancer to expose a simple Nginx application without requiring external AWS Load Balancers.
🏗️ Infrastructure Architecture

The cluster creates a mesh network where all nodes can communicate internally, while still being accessible from the internet for administrative tasks and application traffic.
Code snippet

graph TD
    Client((User / Internet)) -->|HTTP:80 / HTTPS:443| Ingress[Traefik Ingress Controller]
    
    subgraph AWS VPC Public Subnet
        subgraph Security Group [Ports: 22, 6443, 80, 443, 8472]
            Master[Master Node\n(Control Plane)]
            Worker1[Worker Node 1]
            Worker2[Worker Node 2]
        end
    end
    
    Ingress -->|Routes Traffic| Pod1(Nginx Pod)
    Ingress -->|Routes Traffic| Pod2(Nginx Pod)
    
    Master -- "VXLAN (UDP 8472)" --> Worker1
    Master -- "VXLAN (UDP 8472)" --> Worker2
    
    Client -.->|SSH:22| Master
    Client -.->|Kubectl:6443| Master

Component Breakdown

    1x Master Node: Runs the K3s Server (Control Plane + API).

    2x Worker Nodes: Runs the K3s Agent (Workload execution).

    Networking:

        Public Access: All nodes have Public IPs for SSH and HTTP ingress.

        Internal Access: Nodes communicate via Private IPs (VXLAN overlay).

🛠️ Prerequisites

    AWS Account with permissions to create EC2 instances and Security Groups.

    SSH Key Pair (.pem file) for instance access.

    Terminal/CLI with SSH installed.

📋 Task 1: Infrastructure Setup
1. Security Group Rules

Create a single Security Group attached to ALL nodes with the following rules:
Type	Port	Source	Description
SSH	22	My IP	For administrative access.
TCP	6443	0.0.0.0/0	K3s API Server (kubectl access).
TCP	80	0.0.0.0/0	Traefik Ingress (HTTP).
TCP	443	0.0.0.0/0	Traefik Ingress (HTTPS).
UDP	8472	Security Group ID	Flannel CNI (Internal Pod Network).
TCP	10250	Security Group ID	Kubelet Metrics.
2. EC2 Instances

Launch 3 Ubuntu (or Amazon Linux 2) instances in the Public Subnet:

    Instance 1: Tag as K3s-Master

    Instance 2: Tag as K3s-Worker-1

    Instance 3: Tag as K3s-Worker-2

🚀 Task 2: Cluster Bootstrapping
Step 1: Initialize Master Node

SSH into the Master instance and run:
Bash

# Install K3s Server
curl -sfL https://get.k3s.io | sh -

# Extract the Node Token (Required for workers to join)
sudo cat /var/lib/rancher/k3s/server/node-token
# Example output: K10abc123...

# Get Private IP
hostname -i

Step 2: Join Worker Nodes

SSH into each Worker instance and run the following command (replace placeholders):
Bash

curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_PRIVATE_IP>:6443 K3S_TOKEN=<NODE_TOKEN> sh -

Step 3: Verify Cluster

Back on the Master Node, check the status:
Bash

sudo kubectl get nodes
# Expected Output: 3 nodes with STATUS 'Ready'

📦 Task 3: Application Deployment

We deploy a standard Nginx application to demonstrate K3s features.
Deployment Manifest (deployment.yaml)

This configuration includes:

    Deployment: 3 Replicas of Nginx.

    Service (LoadBalancer): Uses Klipper to bind host ports automatically.

    Ingress: Uses Traefik to route traffic.

YAML

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  type: LoadBalancer # Triggers K3s Klipper LB
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: "traefik"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80

Apply the file:
Bash

sudo kubectl apply -f deployment.yaml

🧪 Verification & Access

You can access the application using the Public IP of ANY node in the cluster (Master or Workers).

    Copy the Public IP of your Master node.

    Open Browser: Go to http://<MASTER_PUBLIC_IP>

    Result: You should see the "Welcome to nginx!" default page.

This works because Traefik is listening on port 80 on every node and routing requests to the correct Pods.