data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = var.private_zone
}

resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = var.ttl
  records = [var.primary_record]

  set_identifier = "primary"

  weighted_routing_policy {
    weight = var.primary_weight
  }
}

resource "aws_route53_record" "secondary" {
  count = var.create_secondary_record ? 1 : 0

  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "CNAME"
  ttl     = var.ttl
  records = [var.secondary_record]

  set_identifier = "secondary"

  weighted_routing_policy {
    weight = var.secondary_weight
  }
}
