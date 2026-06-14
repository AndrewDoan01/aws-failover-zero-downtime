variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "primary_db_identifier" {
  description = "Primary RDS database identifier used as the failover event source."
  type        = string
}

variable "secondary_db_identifier" {
  description = "Secondary RDS database identifier used for read replica promotion and lag monitoring."
  type        = string
}

variable "secondary_region" {
  description = "Secondary AWS region where the read replica is deployed."
  type        = string
}

variable "rds_event_categories" {
  description = "RDS event categories that should trigger the failover Lambda."
  type        = list(string)
  default     = ["availability", "failure", "failover"]
}

variable "create_replication_lag_alarm" {
  description = "Whether to create the CloudWatch replication lag alarm."
  type        = bool
  default     = true
}

variable "replication_lag_threshold_seconds" {
  description = "Allowed replica lag threshold in seconds before the alarm fires."
  type        = number
  default     = 5
}

variable "replication_lag_evaluation_periods" {
  description = "Number of periods to evaluate for the replication lag alarm."
  type        = number
  default     = 2
}

variable "replication_lag_period" {
  description = "Alarm period in seconds for the replication lag metric."
  type        = number
  default     = 60
}

variable "lambda_runtime" {
  description = "Lambda runtime used for the failover function."
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 128
}

variable "promoted_backup_retention_days" {
  description = "Backup retention to apply if the replica is promoted."
  type        = number
  default     = 7
}

variable "enable_dry_run" {
  description = "Whether the Lambda should only log intended promotion actions."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to resources created by the module."
  type        = map(string)
  default     = {}
}

variable "github_token" {
  description = "GitHub Personal Access Token with repository dispatch permissions."
  type        = string
  sensitive   = true
  default     = ""
}

variable "primary_postgres_db_identifier" {
  description = "Primary PostgreSQL database identifier used as the failover event source."
  type        = string
  default     = ""
}

variable "secondary_postgres_db_identifier" {
  description = "Secondary PostgreSQL database identifier used for read replica promotion."
  type        = string
  default     = ""
}


