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

variable "routing_policy" {
  description = "Route53 routing policy to use for the record set."
  type        = string
  default     = "FAILOVER"

  validation {
    condition     = contains(["FAILOVER", "WEIGHTED"], upper(var.routing_policy)) && (upper(var.routing_policy) != "FAILOVER" || var.create_secondary_record)
    error_message = "routing_policy must be one of: FAILOVER, WEIGHTED, and FAILOVER requires create_secondary_record to be true."
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

variable "primary_weight" {
  description = "Weight for primary record."
  type        = number
  default     = 100
}

variable "secondary_weight" {
  description = "Weight for secondary record."
  type        = number
  default     = 0
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
