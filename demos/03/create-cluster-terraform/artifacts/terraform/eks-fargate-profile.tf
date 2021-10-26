################################################################################
# Fargate Execution Role
################################################################################

resource "aws_iam_role" "cluster-terraform-fargate-profile" {
  name = "cluster-terraform-fargateRole"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.cluster-terraform-fargate-profile.name
}

resource "aws_iam_role_policy_attachment" "cluster-terraform-fp-wordpress-CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cluster-terraform-fargate-profile.name
}

################################################################################
# Fargate Profile
################################################################################

resource "aws_eks_fargate_profile" "tv" {
  cluster_name           = aws_eks_cluster.cluster-terraform.name
  fargate_profile_name   = "tv"
  pod_execution_role_arn = aws_iam_role.cluster-terraform-fargate-profile.arn
  subnet_ids             = aws_subnet.priv[*].id
  selector {
      namespace = "tv"
      labels = {
        "fargate" = "true"
      }
    }

  tags = {
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }
}

resource "aws_eks_fargate_profile" "wordpress-fargate" {
  cluster_name           = aws_eks_cluster.cluster-terraform.name
  fargate_profile_name   = "wordpress-fargate"
  pod_execution_role_arn = aws_iam_role.cluster-terraform-fargate-profile.arn
  subnet_ids             = aws_subnet.priv[*].id
  selector {
      namespace = "wordpress-fargate"
      labels = {
        "fargate" = "true"
      }
    }

  tags = {
    "CLASS" = "EKS"
    "DEMO" = "create-cluster-terraform"
  }
}
