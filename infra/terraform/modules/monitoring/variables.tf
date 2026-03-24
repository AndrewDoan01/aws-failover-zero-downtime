variable "project_name" {
  description = "Project name used in alarm names."
  type        = string
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
