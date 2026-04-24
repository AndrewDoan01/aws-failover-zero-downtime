data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_openid_connect_provider" "github" {

  url = "https://token.actions.githubusercontent.com"

  tags = var.tags
}

data "aws_iam_policy_document" "assume_role" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {

      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {

      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {

      test = "StringLike"

      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_org}/${var.github_repo}:environment:${var.environment}"
      ]
    }
  }
}

# IAM Role
resource "aws_iam_role" "this" {

  name = var.role_name

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

# ECR Permissions
data "aws_iam_policy_document" "ecr_permissions" {
  # Required for login
  statement {

    sid    = "EcrAuth"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }


  # Push permissions
  statement {

    sid    = "EcrPush"
    effect = "Allow"

    actions = [

      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",

      "ecr:BatchGetImage",
      "ecr:DescribeImages"
    ]

    resources = var.repository_arns
  }
}

# Attach Policy
resource "aws_iam_role_policy" "this" {

  name = "${var.role_name}-policy"

  role = aws_iam_role.this.id

  policy = data.aws_iam_policy_document.ecr_permissions.json
}