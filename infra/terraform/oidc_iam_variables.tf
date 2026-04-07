variable "enable_oidc_iam_roles" {
  description = "Whether to create GitHub OIDC IAM deploy roles."
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub organization or user owning this repository."
  type        = string
  default     = "your-github-org"
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

variable "tf_state_bucket_name" {
  description = "Terraform state S3 bucket name referenced by deploy role policy."
  type        = string
  default     = "replace-me-tf-state-bucket"
}

variable "tf_lock_table_name" {
  description = "Terraform lock DynamoDB table referenced by deploy role policy."
  type        = string
  default     = "replace-me-tf-lock-table"
}
