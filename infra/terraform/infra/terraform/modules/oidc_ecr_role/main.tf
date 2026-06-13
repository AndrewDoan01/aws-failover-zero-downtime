data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Reuse the GitHub OIDC provider so Actions can assume this ECR push role.
data "aws_iam_openid_connect_provider" "github" {

  url = "https://token.actions.githubusercontent.com"

  tags = var.tags
}

# Trust policy for GitHub Actions scoped to this repository.
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
        "repo:${var.github_org}/${var.github_repo}:environment:${var.environment}",
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*",
        "repo:${var.github_org}/${var.github_repo}:ref:refs/tags/*"
      ]
    }
  }
}

# IAM role used by GitHub Actions for ECR pushes.
resource "aws_iam_role" "this" {

  name = var.role_name

  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

# Minimal ECR permissions required to authenticate and push images.
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

# Attach the ECR permissions to the role.
resource "aws_iam_role_policy" "this" {

  name = "${var.role_name}-policy"

  role = aws_iam_role.this.id

  policy = data.aws_iam_policy_document.ecr_permissions.json
}
