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
