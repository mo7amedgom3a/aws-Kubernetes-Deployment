# VPC
# 1. VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true # Required for K8s nodes

  tags = {
    Name                                          = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# 2. Internet Gateway (For Public Subnets)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# 3. Public Subnets (For Load Balancers & Bastion)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.k8s_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned" # Cluster owns these resources
    "kubernetes.io/role/elb"                    = "1"     # TELLS AWS: Create Public Load Balancers here
  }
}

# 4. Private Subnets (For K8s Nodes - Control Plane & Workers)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.k8s_vpc.cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                          = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"     # TELLS AWS: Create Internal Load Balancers here
  }
}

# 5. NAT Gateway (REQUIRED for Private Nodes to download Docker images)
# Note: NAT Gateways cost money (~$0.045/hr). For a cheap lab, you can put nodes in public subnets, 
# but this architecture is the "Production Standard".
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place NAT in Public Subnet

  tags = {
    Name = "${var.cluster_name}-nat"
  }
}

# 6. Route Tables
# Public Route Table -> Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Private Route Table -> NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# 7. Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Data source to get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}