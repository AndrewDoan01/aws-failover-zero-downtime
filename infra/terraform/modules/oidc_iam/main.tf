data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Create the GitHub OIDC provider only when the stack is responsible for managing it.
resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub Actions OIDC root CA thumbprint.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

locals {
  # Fall back to the inferred provider ARN when an external provider is supplied.
  inferred_oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  oidc_provider_arn          = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : coalesce(var.github_oidc_provider_arn, local.inferred_oidc_provider_arn)
  deploy_role_names          = { for environment in var.environments : environment => "${var.role_name_prefix}-${environment}" }
}

data "aws_iam_roles" "existing_deploy_roles" {
  name_regex = "^${var.role_name_prefix}-(${join("|", var.environments)})$"
}

locals {
  existing_deploy_role_names = toset(data.aws_iam_roles.existing_deploy_roles.names)
}

# Build one assume-role policy per deployment environment.
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

# Provision a separate deploy role for each GitHub environment.
resource "aws_iam_role" "deploy" {
  for_each = { for environment in var.environments : environment => environment if !contains(local.existing_deploy_role_names, local.deploy_role_names[environment]) }

  name               = local.deploy_role_names[each.value]
  assume_role_policy = data.aws_iam_policy_document.assume_role[each.value].json
  tags = merge(var.tags, {
    Environment = each.value
  })
}

# Scope each role to the EKS clusters and ECR actions needed for that environment.
data "aws_iam_policy_document" "deploy_permissions" {
  for_each = toset(var.environments)

  statement {
    sid    = "EksDeploy"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:eks:${var.primary_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_primary_region_cluster_name}",
      "arn:${data.aws_partition.current.partition}:eks:${var.primary_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_primary_region_cluster_name}-*"
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
        "arn:${data.aws_partition.current.partition}:eks:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_secondary_region_cluster_name}",
        "arn:${data.aws_partition.current.partition}:eks:${var.secondary_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_secondary_region_cluster_name}-*"
      ]
    }
  }
}

# Attach the environment-specific permissions to the corresponding role.
resource "aws_iam_role_policy" "deploy" {
  for_each = toset(var.environments)

  name   = "${var.role_name_prefix}-${each.value}-policy"
  role   = local.deploy_role_names[each.value]
  policy = data.aws_iam_policy_document.deploy_permissions[each.value].json
}
