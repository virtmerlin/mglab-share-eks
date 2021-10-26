#
# VPC Resources
#  * VPC
#  * Subnets (Pub & Priv)
#  * Internet Gateway
#  * NAT Gateways
#  * Route Tables
#

resource "aws_vpc" "cluster-terraform-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-eks-cluster/VPC"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
    "Name" = "terraform-eks-cluster/VPC"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }

}

resource "aws_subnet" "pub" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.cluster-terraform-vpc.id

  tags = {
    Name = "${var.cluster-name}-Public-${count.index}"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
    "kubernetes.io/role/elb" = "1"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }

}

resource "aws_subnet" "priv" {
  count = 2

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.10${count.index}.0/24"
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.cluster-terraform-vpc.id

  tags = {
    Name = "${var.cluster-name}-Private-${count.index}"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cluster-terraform-vpc.id

  tags = {
    Name = "terraform-eks-cluster/IGW"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }
}

resource "aws_eip" "nat_eip" {
  count = 2
  vpc        = true
  depends_on = [aws_vpc.cluster-terraform-vpc]
  tags = {
    Name  = "${var.cluster-name}-EIP-${count.index}"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  count = 2
  allocation_id = aws_eip.nat_eip.*.id[count.index]
  subnet_id     = aws_subnet.pub.*.id[count.index]
  depends_on    = [aws_internet_gateway.igw]
  tags = {
    Name = "${var.cluster-name}-NAT-${count.index}"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }
}

resource "aws_route_table" "pub" {
  vpc_id = aws_vpc.cluster-terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster-name}-Pub-RT"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }

}

resource "aws_route_table_association" "pub" {
  count = 2

  subnet_id      = aws_subnet.pub.*.id[count.index]
  route_table_id = aws_route_table.pub.id

}

resource "aws_route_table" "priv" {
  count = 2
  vpc_id = aws_vpc.cluster-terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.*.id[count.index]
  }
  tags = {
    Name = "${var.cluster-name}-Priv-RT-${count.index}"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }

}

resource "aws_route_table_association" "priv" {
  count = 2

  subnet_id      = aws_subnet.priv.*.id[count.index]
  route_table_id = aws_route_table.priv.*.id[count.index]
}
