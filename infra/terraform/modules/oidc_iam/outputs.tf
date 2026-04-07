output "role_arns" {
  description = "IAM role ARN by environment for GitHub Actions."
  value       = { for env, role in aws_iam_role.deploy : env => role.arn }
}

output "role_names" {
  description = "IAM role name by environment for GitHub Actions."
  value       = { for env, role in aws_iam_role.deploy : env => role.name }
}
