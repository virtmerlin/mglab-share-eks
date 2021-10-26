#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes
#

################################################################################
# Managed NodeGroup IAM Role
################################################################################

resource "aws_iam_role" "cluster-terraform-noderole-1" {
  name = "cluster-terraform-nodeRole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.cluster-terraform-noderole-1.name
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cluster-terraform-noderole-1.name
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.cluster-terraform-noderole-1.name
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.cluster-terraform-noderole-1.name
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cluster-terraform-noderole-1.name
}

################################################################################
# Managed NodeGroup
################################################################################

resource "aws_eks_node_group" "cluster-terraform-nodegroup-1" {
  cluster_name    = aws_eks_cluster.cluster-terraform.name
  node_group_name = "cluster-terraform-nodegroup-1"
  version = "1.20"
  node_role_arn   = aws_iam_role.cluster-terraform-noderole-1.arn
  subnet_ids      = aws_subnet.priv[*].id

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  tags = {
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
    "k8s.io/cluster-autoscaler/${var.cluster-name}" = "owned"
    "k8s.io/cluster-autoscaler/enabled" = "TRUE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-terraform-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.cluster-terraform-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.cluster-terraform-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.cluster-terraform-AmazonSSMManagedInstanceCore,
    aws_eks_cluster.cluster-terraform,
  ]
}
