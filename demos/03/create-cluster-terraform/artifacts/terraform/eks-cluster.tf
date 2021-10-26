#
# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

################################################################################
# EKS Cluster IAM Role
################################################################################

resource "aws_iam_role" "cluster-terraform-clusterrole" {
  name = "cluster-terraform-clusterRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster-terraform-clusterrole.name
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster-terraform-clusterrole.name
}

################################################################################
# EKS Cluster SG
################################################################################

resource "aws_security_group" "cluster-terraform-sg-cluster" {
  name        = "cluster-terraform-SG-Cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.cluster-terraform-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster-name}-SG-Cluster"
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }
}

resource "aws_security_group_rule" "cluster-terraform-ingress-public-https" {
  cidr_blocks       = [ "0.0.0.0/0" ]
  description       = "Allow Public access to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster-terraform-sg-cluster.id
  to_port           = 443
  type              = "ingress"
}

################################################################################
# EKS Cluster
################################################################################

resource "aws_eks_cluster" "cluster-terraform" {
  name     = var.cluster-name
  version = "1.20"
  enabled_cluster_log_types = ["api", "audit","authenticator","controllerManager","scheduler"]
  role_arn = aws_iam_role.cluster-terraform-clusterrole.arn

  vpc_config {
    security_group_ids = [aws_security_group.cluster-terraform-sg-cluster.id]
    subnet_ids         = aws_subnet.priv[*].id
  }

  tags = {
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-terraform-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-terraform-AmazonEKSVPCResourceController,
  ]
}

################################################################################
# Kubernetes OIDC trust to IAM for IRSA
################################################################################

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.cluster-terraform.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster-terraform.identity[0].oidc[0].issuer
}


################################################################################
# Kubernetes provider configuration to exec K8s/Helm deploys
################################################################################


data "aws_eks_cluster_auth" "cluster-terraform-auth" {
  name = aws_eks_cluster.cluster-terraform.id
}

provider "kubernetes" {
  host                   = aws_eks_cluster.cluster-terraform.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster-terraform.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster-terraform-auth.token
}
