data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub Actions OIDC root CA thumbprint.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

locals {
  inferred_oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  oidc_provider_arn          = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : coalesce(var.github_oidc_provider_arn, local.inferred_oidc_provider_arn)
}

data "aws_iam_policy_document" "assume_role" {
  for_each = toset(var.environments)

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:environment:${each.value}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each = toset(var.environments)

  name               = "${var.role_name_prefix}-${each.value}"
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.value].json
  tags = merge(var.tags, {
    Environment = each.value
  })
}

data "aws_iam_policy_document" "deploy_permissions" {
  for_each = toset(var.environments)

  statement {
    sid    = "EksDeploy"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}",
      "arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}-*"
    ]
  }

  statement {
    sid    = "EcrDigestVerification"
    effect = "Allow"
    actions = [
      "ecr:DescribeImages"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_secondary_eks_permissions ? [1] : []

    content {
      sid    = "EksDeploySecondary"
      effect = "Allow"
      actions = [
        "eks:DescribeCluster"
      ]
      resources = [
        "arn:${data.aws_partition.current.partition}:eks:${var.secondary_aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.secondary_eks_cluster_name}",
        "arn:${data.aws_partition.current.partition}:eks:${var.secondary_aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.secondary_eks_cluster_name}-*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  for_each = toset(var.environments)

  name   = "${var.role_name_prefix}-${each.value}-policy"
  role   = aws_iam_role.deploy[each.value].id
  policy = data.aws_iam_policy_document.deploy_permissions[each.value].json
}
