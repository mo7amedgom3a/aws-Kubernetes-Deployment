# -----------------------------------------------------------
# 1. Trust Policy (Allows EC2 to assume these roles)
# -----------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------
# 2. Control Plane (Master) Role & Profile
# -----------------------------------------------------------
resource "aws_iam_role" "control_plane" {
  name               = "${var.cluster_name}-control-plane-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.cluster_name}-control-plane-role"
  }
}

# Attachments for Control Plane
# Why? The Control Plane runs the "Cloud Controller Manager". 
# It needs to update Route Tables, Security Groups, and Tags.
resource "aws_iam_role_policy_attachment" "cp_ec2" {
  role       = aws_iam_role.control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Why? To manage Load Balancers (Classic & Network)
resource "aws_iam_role_policy_attachment" "cp_elb" {
  role       = aws_iam_role.control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# Why? Required if you use the AWS IAM Authenticator or ECR from the master
resource "aws_iam_role_policy_attachment" "cp_ecr" {
  role       = aws_iam_role.control_plane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# INSTANCE PROFILE (This is what you attach to the EC2 Instance)
resource "aws_iam_instance_profile" "control_plane" {
  name = "${var.cluster_name}-control-plane-profile"
  role = aws_iam_role.control_plane.name
}

# -----------------------------------------------------------
# 3. Worker Node Role & Profile
# -----------------------------------------------------------
resource "aws_iam_role" "worker" {
  name               = "${var.cluster_name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.cluster_name}-worker-role"
  }
}

# Attachments for Workers
# Why? Workers need to pull Docker images from ECR
resource "aws_iam_role_policy_attachment" "worker_ecr" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Why? To allow the EBS CSI Driver (running on nodes) to attach/detach volumes
resource "aws_iam_role_policy_attachment" "worker_ebs" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Why? General worker node permissions (networking, CNI)
resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  # Note: This is an EKS policy, but it contains standard permissions useful for any K8s worker
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Why? Required for the AWS CNI plugin (if you choose to use it)
resource "aws_iam_role_policy_attachment" "worker_cni" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# INSTANCE PROFILE
resource "aws_iam_instance_profile" "worker" {
  name = "${var.cluster_name}-worker-profile"
  role = aws_iam_role.worker.name
}