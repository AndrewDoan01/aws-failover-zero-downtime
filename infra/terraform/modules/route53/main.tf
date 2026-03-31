data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = var.private_zone
}

resource "aws_route53_record" "primary_standard" {
  count = var.create_alias ? 0 : 1

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)
  ttl     = var.ttl
  records = [var.primary_record]

  set_identifier = "primary"

  weighted_routing_policy {
    weight = var.primary_weight
  }
}

resource "aws_route53_record" "primary_alias" {
  count = var.create_alias ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)

  set_identifier = "primary"

  weighted_routing_policy {
    weight = var.primary_weight
  }

  alias {
    name                   = var.primary_alias_name
    zone_id                = var.primary_alias_zone_id
    evaluate_target_health = var.alias_evaluate_target_health
  }
}

resource "aws_route53_record" "secondary_standard" {
  count = var.create_secondary_record && !var.create_alias ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)
  ttl     = var.ttl
  records = [var.secondary_record]

  set_identifier = "secondary"

  weighted_routing_policy {
    weight = var.secondary_weight
  }
}

resource "aws_route53_record" "secondary_alias" {
  count = var.create_secondary_record && var.create_alias ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = upper(var.record_type)

  set_identifier = "secondary"

  weighted_routing_policy {
    weight = var.secondary_weight
  }

  alias {
    name                   = var.secondary_alias_name
    zone_id                = var.secondary_alias_zone_id
    evaluate_target_health = var.alias_evaluate_target_health
  }
}
