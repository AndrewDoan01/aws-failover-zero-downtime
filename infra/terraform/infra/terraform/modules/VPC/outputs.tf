output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of private subnets."
  value       = module.vpc.private_subnets
}

output "nat_public_ips" {
  description = "Public IPs attached to NAT gateways."
  value       = module.vpc.nat_public_ips
}
