variable "zone_name" {
  description = "Route53 hosted zone name (for example: example.com.)."
  type        = string
}

variable "private_zone" {
  description = "Whether the hosted zone is private."
  type        = bool
  default     = false
}

variable "record_name" {
  description = "DNS record name to create."
  type        = string
}

variable "record_type" {
  description = "DNS record type (CNAME, A, AAAA). Use A/AAAA with alias records."
  type        = string
  default     = "CNAME"

  validation {
    condition     = contains(["CNAME", "A", "AAAA"], upper(var.record_type))
    error_message = "record_type must be one of: CNAME, A, AAAA."
  }
}

variable "ttl" {
  description = "TTL for the DNS records in seconds."
  type        = number
  default     = 60
}

variable "primary_record" {
  description = "Primary non-alias record target."
  type        = string
  default     = ""
}

variable "create_alias" {
  description = "Whether to create alias records instead of standard records."
  type        = bool
  default     = false

  validation {
    condition     = !var.create_alias || contains(["A", "AAAA"], upper(var.record_type))
    error_message = "When create_alias is true, record_type must be A or AAAA."
  }
}

variable "primary_alias_name" {
  description = "Primary alias DNS target name (for example, ALB DNS name)."
  type        = string
  default     = ""
}

variable "primary_alias_zone_id" {
  description = "Primary alias target hosted zone ID."
  type        = string
  default     = ""
}

variable "secondary_record" {
  description = "Secondary non-alias record target."
  type        = string
  default     = ""
}

variable "secondary_alias_name" {
  description = "Secondary alias DNS target name."
  type        = string
  default     = ""
}

variable "secondary_alias_zone_id" {
  description = "Secondary alias target hosted zone ID."
  type        = string
  default     = ""
}

variable "alias_evaluate_target_health" {
  description = "Whether Route53 evaluates alias target health."
  type        = bool
  default     = true
}

variable "create_secondary_record" {
  description = "Whether to create secondary weighted record."
  type        = bool
  default     = false
}

variable "primary_health_check_enabled" {
  description = "Whether to create a Route53 health check for the primary target."
  type        = bool
  default     = true
}

variable "primary_health_check_fqdn" {
  description = "Primary health check target FQDN. Falls back to the primary alias or record target when empty."
  type        = string
  default     = ""
}

variable "primary_health_check_port" {
  description = "Primary health check port."
  type        = number
  default     = 443
}

variable "primary_health_check_type" {
  description = "Primary health check protocol."
  type        = string
  default     = "HTTPS"

  validation {
    condition     = contains(["HTTP", "HTTPS"], upper(var.primary_health_check_type))
    error_message = "primary_health_check_type must be HTTP or HTTPS."
  }
}

variable "primary_health_check_resource_path" {
  description = "HTTP path used by the primary health check."
  type        = string
  default     = "/health"
}

variable "primary_health_check_failure_threshold" {
  description = "Number of failed checks before Route53 marks the primary target unhealthy."
  type        = number
  default     = 3
}

variable "primary_health_check_request_interval" {
  description = "Interval in seconds between Route53 health check requests."
  type        = number
  default     = 30
}

variable "primary_health_check_enable_sni" {
  description = "Whether to enable SNI for HTTPS health checks."
  type        = bool
  default     = true
}

variable "primary_health_check_search_string" {
  description = "Optional string Route53 should look for in the health check response body."
  type        = string
  default     = ""
}

variable "primary_health_check_regions" {
  description = "Optional Route53 health check regions. Leave empty for the default managed regions."
  type        = list(string)
  default     = []
}

variable "secondary_health_check_enabled" {
  description = "Whether to create a Route53 health check for the secondary target."
  type        = bool
  default     = true
}

variable "secondary_health_check_fqdn" {
  description = "Secondary health check target FQDN. Falls back to the secondary alias or record target when empty."
  type        = string
  default     = ""
}

variable "secondary_health_check_port" {
  description = "Secondary health check port."
  type        = number
  default     = 80
}

variable "secondary_health_check_type" {
  description = "Secondary health check protocol."
  type        = string
  default     = "HTTP"

  validation {
    condition     = contains(["HTTP", "HTTPS"], upper(var.secondary_health_check_type))
    error_message = "secondary_health_check_type must be HTTP or HTTPS."
  }
}

variable "secondary_health_check_resource_path" {
  description = "HTTP path used by the secondary health check."
  type        = string
  default     = "/"
}

variable "secondary_health_check_failure_threshold" {
  description = "Number of failed checks before Route53 marks the secondary target unhealthy."
  type        = number
  default     = 3
}

variable "secondary_health_check_request_interval" {
  description = "Interval in seconds between Route53 health check requests."
  type        = number
  default     = 30
}

variable "secondary_health_check_enable_sni" {
  description = "Whether to enable SNI for HTTPS health checks."
  type        = bool
  default     = true
}

variable "secondary_health_check_search_string" {
  description = "Optional string Route53 should look for in the health check response body."
  type        = string
  default     = ""
}

variable "secondary_health_check_regions" {
  description = "Optional Route53 health check regions. Leave empty for the default managed regions."
  type        = list(string)
  default     = []
}

variable "create_hosted_zone" {
  description = "Whether to create the Route53 hosted zone instead of looking it up."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID to associate with the created private hosted zone."
  type        = string
  default     = ""
}
