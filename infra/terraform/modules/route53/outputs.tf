output "zone_id" {
  description = "Hosted zone ID."
  value       = data.aws_route53_zone.this.zone_id
}

output "primary_fqdn" {
  description = "FQDN of the primary Route53 record."
  value       = aws_route53_record.primary.fqdn
}

output "secondary_fqdn" {
  description = "FQDN of the secondary Route53 record when created."
  value       = try(aws_route53_record.secondary[0].fqdn, null)
}
