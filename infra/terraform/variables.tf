variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "ap-southeast-1"
}

variable "dr_aws_region" {
  description = "Secondary AWS region used for passive DR naming and grouping."
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_access_key_id" {
  description = "AWS access key ID (optional, prefer environment/shared credentials when possible)."
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_secret_access_key" {
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

variable "vpc_name" {
  description = "VPC name."
  type        = string
  default     = "ha-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones used by VPC."
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "vpc_private_subnets" {
  description = "Private subnets for internal workloads."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "vpc_public_subnets" {
  description = "Public subnets for internet-facing workloads."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "secondary_vpc_name" {
  description = "Secondary region VPC name."
  type        = string
  default     = "secondary_vpc"
}

variable "secondary_vpc_cidr" {
  description = "CIDR block for secondary region VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "secondary_vpc_azs" {
  description = "Availability zones used by secondary VPC."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "secondary_vpc_private_subnets" {
  description = "Private subnets for secondary VPC workloads."
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "secondary_vpc_public_subnets" {
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

variable "eks_cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "ha-eks"
}

variable "enable_passive_cluster" {
  description = "Whether passive DR cluster naming and grouping are enabled."
  type        = bool
  default     = false
}

variable "passive_eks_cluster_name" {
  description = "Passive DR EKS cluster name in secondary region."
  type        = string
  default     = ""
}

variable "passive_node_desired_size" {
  description = "Desired node count for passive secondary EKS cluster."
  type        = number
  default     = 0
}

variable "passive_node_min_size" {
  description = "Minimum node count for passive secondary EKS cluster."
  type        = number
  default     = 0
}

variable "passive_node_max_size" {
  description = "Maximum node count for passive secondary EKS cluster."
  type        = number
  default     = 1
}

variable "create_cluster_resource_groups" {
  description = "Whether to create AWS Resource Groups for cluster-centric operations."
  type        = bool
  default     = true
}

variable "enable_route53" {
  description = "Whether to create Route53 records."
  type        = bool
  default     = false
}

variable "route53_zone_name" {
  description = "Hosted zone name (example: example.com.)."
  type        = string
  default     = ""
}

variable "route53_private_zone" {
  description = "Whether Route53 zone is private."
  type        = bool
  default     = false
}

variable "route53_record_name" {
  description = "DNS record name."
  type        = string
  default     = ""
}

variable "route53_record_type" {
  description = "DNS record type (CNAME, A, AAAA). Use A/AAAA when alias is enabled."
  type        = string
  default     = "CNAME"
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
  description = "Whether to create secondary weighted record."
  type        = bool
  default     = false
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

variable "route53_primary_weight" {
  description = "Weighted routing weight for primary record."
  type        = number
  default     = 100
}

variable "route53_secondary_weight" {
  description = "Weighted routing weight for secondary record."
  type        = number
  default     = 0
}
