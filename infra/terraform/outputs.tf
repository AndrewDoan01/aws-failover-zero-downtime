output "oidc_deploy_role_arns" {
  description = "OIDC IAM role ARNs by environment for GitHub Environment secrets."
  value       = try(module.oidc_iam[0].role_arns, {})
}

output "oidc_deploy_role_names" {
  description = "OIDC IAM role names by environment."
  value       = try(module.oidc_iam[0].role_names, {})
}
