output "zone_id" {
  description = "Hosted zone ID."
  value       = data.aws_route53_zone.this.zone_id
}

output "primary_fqdn" {
  description = "FQDN of the primary Route53 record."
  value       = try(aws_route53_record.primary_standard[0].fqdn, aws_route53_record.primary_alias[0].fqdn, null)
}

output "secondary_fqdn" {
  description = "FQDN of the secondary Route53 record when created."
  value       = try(aws_route53_record.secondary_standard[0].fqdn, aws_route53_record.secondary_alias[0].fqdn, null)
}
