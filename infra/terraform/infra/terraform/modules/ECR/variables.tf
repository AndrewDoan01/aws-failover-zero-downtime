variable "repositories" {
  description = "List of repositories to create. Each entry defines the repository name and optional settings."
  type = list(object({
    name                 = string
    image_tag_mutability = optional(string)
    scan_on_push         = optional(bool)
    encryption_type      = optional(string)
    kms_key              = optional(string)
    tags                 = optional(map(string))
    lifecycle_policy     = optional(string)
    policy               = optional(string)
  }))
  default = []
}

variable "image_tag_mutability" {
  type    = string
  default = "MUTABLE"
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "encryption_type" {
  type    = string
  default = "AES256"
}

variable "kms_key" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
