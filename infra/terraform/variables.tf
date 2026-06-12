variable "primary_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "secondary_region" {
  description = "Secondary AWS region used for passive DR naming and grouping."
  type        = string
  default     = "ap-northeast-1"
}

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key ID (optional, prefer environment/shared credentials when possible)."
  type        = string
  default     = null
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS secret access key (optional, prefer environment/shared credentials when possible)."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_session_token" {
  description = "AWS session token for temporary credentials (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_profile" {
  description = "AWS named profile to use when resolving credentials (optional)."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name used across resources."
  type        = string
  default     = "aws-ha-zero-downtime"
}

variable "tags" {
  description = "Extra tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_primary_name" {
  description = "VPC name."
  type        = string
  default     = "ha-vpc"
}

variable "vpc_primary_cidr" {
  description = "CIDR block for VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_primary_azs" {
  description = "Availability zones used by VPC."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "vpc_primary_private_subnets" {
  description = "Private subnets for internal workloads."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "vpc_primary_public_subnets" {
  description = "Public subnets for internet-facing workloads."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "vpc_secondary_name" {
  description = "Secondary region VPC name."
  type        = string
  default     = "secondary_vpc"
}

variable "vpc_secondary_cidr" {
  description = "CIDR block for secondary region VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "vpc_secondary_azs" {
  description = "Availability zones used by secondary VPC."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "vpc_secondary_private_subnets" {
  description = "Private subnets for secondary VPC workloads."
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "vpc_secondary_public_subnets" {
  description = "Public subnets for secondary VPC internet-facing resources."
  type        = list(string)
  default     = ["10.1.101.0/24", "10.1.102.0/24"]
}

variable "db_identifier" {
  description = "RDS instance identifier."
  type        = string
  default     = "ha-db"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database master username."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database master password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 41
    error_message = "db_password must be 8 to 41 characters for AWS RDS."
  }

  validation {
    condition     = length(regexall("[/@\"[:space:]]", var.db_password)) == 0
    error_message = "db_password must not contain '/', '@', double quotes, or spaces for AWS RDS MasterUserPassword."
  }
}

variable "db_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the database port."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "db_allowed_security_group_ids" {
  description = "Security group IDs allowed to connect to the database port."
  type        = list(string)
  default     = []
}

variable "eks_primary_region_cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "eks-ap-southeast-1"
}

variable "eks_admin_principal_arn" {
  description = "IAM principal ARN to grant EKS cluster admin access. Defaults to the identity running Terraform when empty."
  type        = string
  default     = null
}

variable "enable_secondary_cluster" {
  description = "Whether passive DR cluster naming and grouping are enabled."
  type        = bool
  default     = true
}

variable "enable_db_failover_automation" {
  description = "Whether to create Lambda-based RDS failover automation and replication lag alarms."
  type        = bool
  default     = true
}

variable "rds_failover_event_categories" {
  description = "RDS event categories that should trigger the failover Lambda."
  type        = list(string)
  default     = ["availability", "failure", "failover"]
}

variable "enable_rds_replication_lag_alarm" {
  description = "Whether to create the CloudWatch alarm for replica lag."
  type        = bool
  default     = true
}

variable "rds_replication_lag_threshold_seconds" {
  description = "Maximum allowed replica lag before the alarm fires."
  type        = number
  default     = 5
}

variable "rds_replication_lag_evaluation_periods" {
  description = "Number of periods to evaluate for the replication lag alarm."
  type        = number
  default     = 2
}

variable "rds_replication_lag_period_seconds" {
  description = "Period in seconds for the replication lag alarm."
  type        = number
  default     = 60
}

variable "eks_secondary_region_cluster_name" {
  description = "Passive DR EKS cluster name in secondary region."
  type        = string
  default     = "eks-ap-northeast-1"
}

variable "eks_secondary_node_desired_size" {
  description = "Desired node count for passive secondary EKS cluster."
  type        = number
  default     = 2
}

variable "eks_secondary_node_min_size" {
  description = "Minimum node count for passive secondary EKS cluster."
  type        = number
  default     = 1
}

variable "eks_secondary_node_max_size" {
  description = "Maximum node count for passive secondary EKS cluster."
  type        = number
  default     = 4
}

variable "create_cluster_resource_groups" {
  description = "Whether to create AWS Resource Groups for cluster-centric operations."
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Whether to create Prometheus and Grafana monitoring workspaces."
  type        = bool
  default     = false
}

variable "monitoring_alarm_topic_name" {
  description = "SNS topic name used by monitoring alarms."
  type        = string
  default     = "infra-alerts"
}

variable "monitoring_prometheus_workspace_alias" {
  description = "Alias assigned to the Amazon Managed Prometheus workspace."
  type        = string
  default     = ""
}

variable "monitoring_prometheus_logging_group_arn" {
  description = "Optional CloudWatch Logs group ARN for Prometheus query logging."
  type        = string
  default     = ""
}

variable "monitoring_grafana_description" {
  description = "Description assigned to the Grafana workspace."
  type        = string
  default     = "Observability workspace"
}

variable "enable_route53" {
  description = "Whether to create Route53 records."
  type        = bool
  default     = true
}

variable "route53_zone_name" {
  description = "Hosted zone name (example: example.com.)."
  type        = string
  default     = ""
}

variable "route53_private_zone" {
  description = "Whether Route53 zone is private."
  type        = bool
  default     = true
}

variable "route53_record_name" {
  description = "DNS record name."
  type        = string
  default     = ""
}

variable "route53_record_type" {
  description = "DNS record type (CNAME, A, AAAA). Use A/AAAA when alias is enabled."
  type        = string
  default     = "A"
}

variable "route53_primary_record" {
  description = "Primary DNS target."
  type        = string
  default     = ""
}

variable "route53_create_alias" {
  description = "Whether to create alias records instead of standard records."
  type        = bool
  default     = false
}

variable "route53_primary_alias_name" {
  description = "Primary alias DNS target name (for example, ALB DNS name)."
  type        = string
  default     = ""
}

variable "route53_primary_alias_zone_id" {
  description = "Primary alias target hosted zone ID."
  type        = string
  default     = ""
}

variable "route53_create_secondary_record" {
  description = "Whether to create the secondary failover record."
  type        = bool
  default     = true
}

variable "route53_secondary_record" {
  description = "Secondary DNS target."
  type        = string
  default     = ""
}

variable "route53_secondary_alias_name" {
  description = "Secondary alias DNS target name."
  type        = string
  default     = ""
}

variable "route53_secondary_alias_zone_id" {
  description = "Secondary alias target hosted zone ID."
  type        = string
  default     = ""
}

variable "route53_alias_evaluate_target_health" {
  description = "Whether Route53 evaluates alias target health."
  type        = bool
  default     = true
}

variable "route53_primary_health_check_enabled" {
  description = "Whether to create the primary Route53 health check."
  type        = bool
  default     = true
}

variable "route53_primary_health_check_fqdn" {
  description = "Health check FQDN for the primary endpoint. Falls back to the primary alias name or record target when empty."
  type        = string
  default     = ""
}

variable "route53_primary_health_check_port" {
  description = "Primary Route53 health check port."
  type        = number
  default     = 80
}

variable "route53_primary_health_check_type" {
  description = "Primary Route53 health check type."
  type        = string
  default     = "HTTP"
}

variable "route53_primary_health_check_resource_path" {
  description = "HTTP path checked by Route53 on the primary endpoint."
  type        = string
  default     = "/health"
}

variable "route53_primary_health_check_failure_threshold" {
  description = "Number of failed checks before Route53 marks the primary endpoint unhealthy."
  type        = number
  default     = 3
}

variable "route53_primary_health_check_request_interval" {
  description = "Seconds between Route53 health check requests."
  type        = number
  default     = 30
}

variable "route53_primary_health_check_enable_sni" {
  description = "Whether to enable SNI for the primary HTTPS health check."
  type        = bool
  default     = true
}

variable "route53_primary_health_check_search_string" {
  description = "Optional text that Route53 must find in the health check response body."
  type        = string
  default     = ""
}

variable "route53_primary_health_check_regions" {
  description = "Optional Route53 health check regions. Leave empty for the default managed regions."
  type        = list(string)
  default     = []
}

variable "route53_secondary_health_check_enabled" {
  description = "Whether to create the secondary Route53 health check."
  type        = bool
  default     = true
}

variable "route53_secondary_health_check_fqdn" {
  description = "Health check FQDN for the secondary endpoint. Falls back to the secondary alias name or record target when empty."
  type        = string
  default     = ""
}

variable "route53_secondary_health_check_port" {
  description = "Secondary Route53 health check port."
  type        = number
  default     = 80
}

variable "route53_secondary_health_check_type" {
  description = "Secondary Route53 health check type."
  type        = string
  default     = "HTTP"
}

variable "route53_secondary_health_check_resource_path" {
  description = "HTTP path checked by Route53 on the secondary endpoint."
  type        = string
  default     = "/health"
}

variable "route53_secondary_health_check_failure_threshold" {
  description = "Number of failed checks before Route53 marks the secondary endpoint unhealthy."
  type        = number
  default     = 3
}

variable "route53_secondary_health_check_request_interval" {
  description = "Seconds between Route53 health check requests."
  type        = number
  default     = 30
}

variable "route53_secondary_health_check_enable_sni" {
  description = "Whether to enable SNI for the secondary HTTPS health check."
  type        = bool
  default     = true
}

variable "route53_secondary_health_check_search_string" {
  description = "Optional text that Route53 must find in the health check response body."
  type        = string
  default     = ""
}

variable "route53_secondary_health_check_regions" {
  description = "Optional Route53 health check regions. Leave empty for the default managed regions."
  type        = list(string)
  default     = []
}

variable "route53_create_hosted_zone" {
  description = "Whether to create the Route53 hosted zone automatically instead of looking it up."
  type        = bool
  default     = true
}
