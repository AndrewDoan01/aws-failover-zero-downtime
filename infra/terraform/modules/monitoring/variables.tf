variable "project_name" {
  description = "Project name used in alarm names."
  type        = string
}

variable "create_prometheus_workspace" {
  description = "Whether to create an Amazon Managed Prometheus workspace."
  type        = bool
  default     = true
}

variable "prometheus_workspace_alias" {
  description = "Alias assigned to the Prometheus workspace."
  type        = string
  default     = ""
}

variable "prometheus_logging_group_arn" {
  description = "Optional CloudWatch Logs group ARN for Prometheus query logging."
  type        = string
  default     = ""
}

variable "create_grafana_workspace" {
  description = "Whether to create an Amazon Managed Grafana workspace."
  type        = bool
  default     = true
}

variable "grafana_account_access_type" {
  description = "Grafana workspace account access type."
  type        = string
  default     = "CURRENT_ACCOUNT"
}

variable "grafana_authentication_providers" {
  description = "Grafana authentication providers."
  type        = list(string)
  default     = ["AWS_SSO"]
}

variable "grafana_permission_type" {
  description = "Grafana workspace permission model."
  type        = string
  default     = "SERVICE_MANAGED"
}

variable "grafana_data_sources" {
  description = "Grafana data sources enabled for the workspace."
  type        = list(string)
  default     = ["PROMETHEUS", "CLOUDWATCH"]
}

variable "grafana_description" {
  description = "Grafana workspace description."
  type        = string
  default     = "Observability workspace"
}

variable "alarm_topic_name" {
  description = "SNS topic name for operational alerts."
  type        = string
  default     = "infra-alerts"
}

variable "rds_instance_id" {
  description = "RDS instance identifier to monitor."
  type        = string
  default     = null
  nullable    = true
}

variable "eks_cluster_name" {
  description = "EKS cluster name to monitor."
  type        = string
  default     = null
  nullable    = true
}

variable "create_rds_cpu_alarm" {
  description = "Whether to create the RDS CPU alarm."
  type        = bool
  default     = true
}

variable "create_eks_failed_requests_alarm" {
  description = "Whether to create the EKS failed requests alarm."
  type        = bool
  default     = true
}

variable "cpu_alarm_threshold" {
  description = "CPU alarm threshold percentage for RDS."
  type        = number
  default     = 80
}

variable "evaluation_periods" {
  description = "Number of periods to evaluate alarm threshold."
  type        = number
  default     = 2
}

variable "period" {
  description = "Alarm period in seconds."
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags to apply to monitoring resources."
  type        = map(string)
  default     = {}
}
