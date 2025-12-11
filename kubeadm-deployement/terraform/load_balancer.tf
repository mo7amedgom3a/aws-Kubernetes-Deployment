# Network Load Balancer for Kubernetes Cluster
# This NLB provides a stable endpoint for:
# 1. Kubernetes API Server (port 6443)
# 2. Application traffic (HTTP/HTTPS via NodePorts)

# Network Load Balancer
resource "aws_lb" "k8s_nlb" {
  name               = "${var.cluster_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

  tags = {
    Name                                        = "${var.cluster_name}-nlb"
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Target Group for Kubernetes API Server (port 6443)
resource "aws_lb_target_group" "k8s_api" {
  name     = "${var.cluster_name}-api-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = aws_vpc.k8s_vpc.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = 6443
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = {
    Name        = "${var.cluster_name}-api-target-group"
    Environment = var.environment
  }
}

# Target Group for Application Traffic (HTTP/HTTPS via NodePorts)
resource "aws_lb_target_group" "k8s_apps_http" {
  name     = "${var.cluster_name}-http-tg"
  port     = 30080
  protocol = "TCP"
  vpc_id   = aws_vpc.k8s_vpc.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = 30080
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = {
    Name        = "${var.cluster_name}-http-target-group"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "k8s_apps_https" {
  name     = "${var.cluster_name}-https-tg"
  port     = 30443
  protocol = "TCP"
  vpc_id   = aws_vpc.k8s_vpc.id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = 30443
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = {
    Name        = "${var.cluster_name}-https-target-group"
    Environment = var.environment
  }
}

# Attach Master Node to API Server Target Group
resource "aws_lb_target_group_attachment" "api_master" {
  target_group_arn = aws_lb_target_group.k8s_api.arn
  target_id        = aws_instance.control_plane.id
  port             = 6443
}

# Attach Worker Nodes to API Server Target Group (for HA setup)
resource "aws_lb_target_group_attachment" "api_workers" {
  count            = length(aws_instance.worker)
  target_group_arn = aws_lb_target_group.k8s_api.arn
  target_id        = aws_instance.worker[count.index].id
  port             = 6443
}

# Attach Worker Nodes to HTTP Target Group
resource "aws_lb_target_group_attachment" "http_workers" {
  count            = length(aws_instance.worker)
  target_group_arn = aws_lb_target_group.k8s_apps_http.arn
  target_id        = aws_instance.worker[count.index].id
  port             = 30080
}

# Attach Worker Nodes to HTTPS Target Group
resource "aws_lb_target_group_attachment" "https_workers" {
  count            = length(aws_instance.worker)
  target_group_arn = aws_lb_target_group.k8s_apps_https.arn
  target_id        = aws_instance.worker[count.index].id
  port             = 30443
}

# Listener for Kubernetes API Server (port 6443)
resource "aws_lb_listener" "k8s_api" {
  load_balancer_arn = aws_lb.k8s_nlb.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api.arn
  }
}

# Listener for HTTP traffic (port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.k8s_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_apps_http.arn
  }
}

# Listener for HTTPS traffic (port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.k8s_nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_apps_https.arn
  }
}
