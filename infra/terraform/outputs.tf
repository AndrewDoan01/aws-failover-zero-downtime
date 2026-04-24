output "oidc_deploy_role_arns" {
  description = "OIDC IAM role ARNs by environment for GitHub Environment secrets."
  value       = try(module.oidc_iam[0].role_arns, {})

}

output "oidc_deploy_role_names" {
  description = "OIDC IAM role names by environment."
  value       = try(module.oidc_iam[0].role_names, {})
}

output "primary_eks_cluster_name" {
  description = "Primary EKS cluster name for deployment workflows."
  value       = module.primary_eks.cluster_name
}

output "secondary_eks_cluster_name" {
  description = "Secondary EKS cluster name when passive cluster is enabled."
  value       = try(module.secondary_eks[0].cluster_name, null)
}

output "github_ecr_role_arn" {

  value = module.github_ecr_role.role_arn
}
