# AMI: Ubuntu 22.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# KEY PAIR (Make sure you created this manually in AWS Console or via CLI)
variable "key_name" {
  default = "my-aws-keys"
}

# --- CONTROL PLANE NODE ---
resource "aws_instance" "control_plane" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"             # Minimum for Master (2 vCPU, 4GB RAM)
  subnet_id     = aws_subnet.public[0].id # Place in Public Subnet

  # Attach Identity & Security
  iam_instance_profile   = aws_iam_instance_profile.control_plane.name
  vpc_security_group_ids = [aws_security_group.k8s_master_sg.id]
  key_name               = var.key_name

  tags = {
    Name                                        = "${var.cluster_name}-control-plane"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  # User data script for Kubernetes node setup
  user_data = "export NODE_TYPE=\"master\"\n${file("k8s-node-setup.sh")}"
}

# --- WORKER NODES ---
resource "aws_instance" "worker" {
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small" # Workers can be smaller
  subnet_id     = aws_subnet.public[count.index].id

  iam_instance_profile   = aws_iam_instance_profile.worker.name
  vpc_security_group_ids = [aws_security_group.k8s_worker_sg.id]
  key_name               = var.key_name

  tags = {
    Name                                        = "${var.cluster_name}-worker-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  # Same script as Control Plane
  user_data = "export NODE_TYPE=\"worker\"\n${file("k8s-node-setup.sh")}"
}
