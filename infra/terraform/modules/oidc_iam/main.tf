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
      values   = [
        "repo:${var.github_org}/${var.github_repo}:environment:${each.value}",
        "repo:${var.github_org}/aws-retail-store-sample-app:*"
      ]
    }
  }
}

# Provision a separate deploy role for each GitHub environment.
# Manage roles directly in Terraform state without unsafe dynamic lookup filters.
resource "aws_iam_role" "deploy" {
  for_each = toset(var.environments)

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
    sid    = "EcrAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushAndDescribe"
    effect = "Allow"
    actions = [
      "ecr:DescribeImages",
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage"
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
# Directly reference aws_iam_role.deploy resource to establish a dependency graph.
resource "aws_iam_role_policy" "deploy" {
  for_each = toset(var.environments)

  name   = "${var.role_name_prefix}-${each.value}-policy"
  role   = aws_iam_role.deploy[each.value].name
  policy = data.aws_iam_policy_document.deploy_permissions[each.value].json
}
