# OIDC IAM Model Per Environment

Create one IAM role per environment and map each role to the matching GitHub Environment secret `AWS_ROLE_ARN`.

- test: `gha-infra-deploy-test`
- staging: `gha-infra-deploy-staging`
- prod: `gha-infra-deploy-prod`

## Trust Policy Template

Replace account/repo values before applying:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<aws-account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:<org>/<repo>:environment:test",
            "repo:<org>/<repo>:environment:staging",
            "repo:<org>/<repo>:environment:prod"
          ]
        }
      }
    }
  ]
}
```

For strict isolation, create one role per environment and keep only one `sub` entry per role.

## Permission Scope Template

Grant minimum set for deployment and state backend access only.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": [
        "arn:aws:s3:::<tf-state-bucket>",
        "arn:aws:s3:::<tf-state-bucket>/*",
        "arn:aws:dynamodb:<region>:<aws-account-id>:table/<tf-lock-table>"
      ]
    },
    {
      "Sid": "EksDeploy",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster"
      ],
      "Resource": "arn:aws:eks:<region>:<aws-account-id>:cluster/<cluster-name>"
    },
    {
      "Sid": "EcrDigestVerification",
      "Effect": "Allow",
      "Action": [
        "ecr:DescribeImages"
      ],
      "Resource": "*"
    }
  ]
}
```

Do not grant image build or push permissions in this infra repository role.
