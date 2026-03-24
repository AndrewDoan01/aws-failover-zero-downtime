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

variable "ttl" {
  description = "TTL for the DNS records in seconds."
  type        = number
  default     = 60
}

variable "primary_record" {
  description = "Primary CNAME record target."
  type        = string
}

variable "secondary_record" {
  description = "Secondary CNAME record target."
  type        = string
  default     = ""
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
