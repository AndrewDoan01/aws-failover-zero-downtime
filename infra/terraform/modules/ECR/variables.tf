variable "repositories" {
  description = "List of repositories to create. Each entry is a map with keys: name, image_tag_mutability, scan_on_push, encryption_type, kms_key, tags, lifecycle_policy, policy"
  type        = list(map(any))
  default     = []
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
