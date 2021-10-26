data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  k8s_service_account_namespace = "kube-system"
  k8s_service_account_name      = "cluster-autoscaler"
}

################################################################################
# IRSA IAM Role & Policy for Cluster Autoscaler
################################################################################

data "aws_iam_policy_document" "irsa_cluster_autoscaler_assume_role_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cluster-terraform-irsa-cluster-autoscaler-role" {
  assume_role_policy = data.aws_iam_policy_document.irsa_cluster_autoscaler_assume_role_trust_policy.json
  name               = "cluster-terraform-irsa-cluster-autoscalerRole"
}

resource "aws_iam_policy" "irsa_cluster_autoscaler_policy" {
  name        = "cluster-terraform-irsa-cluster-autoscaler-policy"
  path        = "/"
  description = "For the Cluster Autoscaler"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "irsa_cluster_autoscaler_policy_attachment" {
  policy_arn = aws_iam_policy.irsa_cluster_autoscaler_policy.arn
  role       = aws_iam_role.cluster-terraform-irsa-cluster-autoscaler-role.name

  depends_on = [
    aws_iam_policy.irsa_cluster_autoscaler_policy,
    aws_iam_role.cluster-terraform-irsa-cluster-autoscaler-role,
   ]
}

################################################################################
# Helm Deploy of Cluster Autoscaler + set IRSA Svc Account Annotation
################################################################################

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.cluster-terraform.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.cluster-terraform.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster-terraform-auth.token
  }
}

resource "helm_release" "cluster-autoscaler" {
  depends_on = [
    aws_eks_cluster.cluster-terraform,
    aws_iam_policy.irsa_cluster_autoscaler_policy,
    aws_iam_role.cluster-terraform-irsa-cluster-autoscaler-role,
    aws_iam_role_policy_attachment.irsa_cluster_autoscaler_policy_attachment,
  ]

  name             = "cluster-autoscaler"
  namespace        = local.k8s_service_account_namespace
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = "9.10.7"
  create_namespace = false

  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = local.k8s_service_account_name
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster-terraform-irsa-cluster-autoscaler-role.arn
    type  = "string"
  }
  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster-name
  }
  set {
    name  = "autoDiscovery.enabled"
    value = "true"
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
}
