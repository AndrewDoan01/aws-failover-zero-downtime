variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "environment" {
  type = string
}

variable "repository_arns" {
  description = "List of ECR repository ARNs allowed to push"
  type        = list(string)
}

variable "role_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

