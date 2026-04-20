variable "enable_oidc_iam_roles" {
  description = "Whether to create GitHub OIDC IAM deploy roles."
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub organization or user owning this repository."
  type        = string
  default     = "AndrewDoan01"
}

variable "github_repo" {
  description = "GitHub repository name used in OIDC subject condition."
  type        = string
  default     = "aws-ha-zero-downtime"
}

variable "oidc_role_name_prefix" {
  description = "Prefix for OIDC deploy IAM roles."
  type        = string
  default     = "gha-infra-deploy"
}

variable "oidc_deploy_environments" {
  description = "Deployment environments that map to GitHub Environments."
  type        = list(string)
  default     = ["test", "staging", "prod"]
}

variable "create_github_oidc_provider" {
  description = "Whether to create GitHub Actions OIDC provider in this AWS account."
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN. Used when create_github_oidc_provider is false."
  type        = string
  default     = null
}
