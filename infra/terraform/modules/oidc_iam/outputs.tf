output "role_arns" {
  description = "IAM role ARN by environment for GitHub Actions."
  value       = { for env, role in aws_iam_role.deploy : env => role.arn }
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN used by deploy roles."
  value       = local.oidc_provider_arn
}

output "role_names" {
  description = "IAM role name by environment for GitHub Actions."
  value       = { for env, role in aws_iam_role.deploy : env => role.name }
}
