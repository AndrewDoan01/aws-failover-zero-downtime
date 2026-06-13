variable "name" {
  description = "Name of the VPC."
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "List of availability zones to use."
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks."
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to enable NAT gateway(s)."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Whether to create a single shared NAT gateway."
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Whether to enable a VPN gateway."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to VPC resources."
  type        = map(string)
  default     = {}
}
