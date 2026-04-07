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

variable "tf_state_bucket_name" {
  description = "S3 bucket name used for Terraform state backend."
  type        = string
}

variable "tf_lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
}

variable "aws_region" {
  description = "AWS region used to build regional ARNs."
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name allowed for DescribeCluster."
  type        = string
}

variable "tags" {
  description = "Common tags applied to IAM roles."
  type        = map(string)
  default     = {}
}