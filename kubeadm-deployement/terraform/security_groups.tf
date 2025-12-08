# Security Group for Master Node
resource "aws_security_group" "k8s_master_sg" {
  name_prefix = "${var.cluster_name}-master-"
  vpc_id      = aws_vpc.k8s_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # etcd server client API
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  # kube-scheduler
  ingress {
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    self        = true
  }

  # kube-controller-manager
  ingress {
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    self        = true
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-master-sg"
    Environment = var.environment
  }
}

# Security Group for Worker Nodes
resource "aws_security_group" "k8s_worker_sg" {
  name_prefix = "${var.cluster_name}-worker-"
  vpc_id      = aws_vpc.k8s_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  # NodePort services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow traffic from master node
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.k8s_master_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-worker-sg"
    Environment = var.environment
  }
}

# Security Group for Load Balancer
resource "aws_security_group" "k8s_lb_sg" {
  name_prefix = "${var.cluster_name}-lb-"
  vpc_id      = aws_vpc.k8s_vpc.id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-lb-sg"
    Environment = var.environment
  }
}
