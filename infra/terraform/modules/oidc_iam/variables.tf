variable "github_org" {
  description = "GitHub organization or user owning the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "role_name_prefix" {
  description = "Prefix used to build role names per environment."
  type        = string
  default     = "gha-infra-deploy"
}

variable "environments" {
  description = "Deployment environments mapped to GitHub Environments."
  type        = list(string)
  default     = ["test", "staging", "prod"]
}

variable "primary_region" {
  description = "AWS region used to build regional ARNs."
  type        = string
}

variable "eks_primary_region_cluster_name" {
  description = "EKS cluster name allowed for DescribeCluster."
  type        = string
}

variable "enable_secondary_eks_permissions" {
  description = "Whether to include DescribeCluster permission for secondary EKS cluster."
  type        = bool
  default     = false
}

variable "secondary_region" {
  description = "Secondary AWS region used for secondary EKS permissions."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_secondary_eks_permissions || (var.secondary_region != null && length(trimspace(var.secondary_region)) > 0)
    error_message = "secondary_region must be set when enable_secondary_eks_permissions is true."
  }
}

variable "eks_secondary_region_cluster_name" {
  description = "Secondary EKS cluster name allowed for DescribeCluster when enabled."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_secondary_eks_permissions || (var.eks_secondary_region_cluster_name != null && length(trimspace(var.eks_secondary_region_cluster_name)) > 0)
    error_message = "eks_secondary_region_cluster_name must be set when enable_secondary_eks_permissions is true."
  }
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider in this AWS account."
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN. Used when create_github_oidc_provider is false."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to IAM roles."
  type        = map(string)
  default     = {}
}
