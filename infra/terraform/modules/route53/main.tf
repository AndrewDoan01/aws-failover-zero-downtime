data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = var.private_zone
}

locals {
  # Resolve the health check target from the most specific input available.
  primary_health_check_target = length(trimspace(var.primary_health_check_fqdn)) > 0 ? var.primary_health_check_fqdn : (
    length(trimspace(var.primary_alias_name)) > 0 ? var.primary_alias_name : var.primary_record
  )
}

# Health check the primary endpoint so Route 53 can fail over when it stops returning healthy responses.
resource "aws_route53_health_check" "primary" {
  count = var.primary_health_check_enabled ? 1 : 0

  fqdn              = local.primary_health_check_target
  port              = var.primary_health_check_port
  type              = upper(var.primary_health_check_type)
  resource_path     = contains(["HTTP", "HTTPS"], upper(var.primary_health_check_type)) ? var.primary_health_check_resource_path : null
  failure_threshold = var.primary_health_check_failure_threshold
  request_interval  = var.primary_health_check_request_interval
  enable_sni        = upper(var.primary_health_check_type) == "HTTPS" ? var.primary_health_check_enable_sni : null
  search_string     = length(trimspace(var.primary_health_check_search_string)) > 0 ? var.primary_health_check_search_string : null
  regions           = length(var.primary_health_check_regions) > 0 ? var.primary_health_check_regions : null
}

# Primary record that receives traffic while the primary region is healthy.
resource "aws_route53_record" "primary_standard" {
  count = var.create_alias ? 0 : 1

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)
  ttl     = var.ttl
  records = [var.primary_record]

  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = var.primary_health_check_enabled ? aws_route53_health_check.primary[0].id : null
}

# Alias form of the primary record for ALB or other alias targets.
resource "aws_route53_record" "primary_alias" {
  count = var.create_alias ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)

  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = var.primary_alias_name
    zone_id                = var.primary_alias_zone_id
    evaluate_target_health = var.alias_evaluate_target_health
  }

  health_check_id = var.primary_health_check_enabled ? aws_route53_health_check.primary[0].id : null
}

# Secondary standard record that Route 53 can promote during failover.
resource "aws_route53_record" "secondary_standard" {
  count = var.create_secondary_record && !var.create_alias ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)
  ttl     = var.ttl
  records = [var.secondary_record]

  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = null
}

# Secondary alias record that serves as the fallback target in failover mode.
resource "aws_route53_record" "secondary_alias" {
  count = var.create_secondary_record && var.create_alias ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)

  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.secondary_alias_name
    zone_id                = var.secondary_alias_zone_id
    evaluate_target_health = var.alias_evaluate_target_health
  }

  health_check_id = null
}
