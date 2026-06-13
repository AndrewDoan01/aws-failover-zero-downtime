output "oidc_deploy_role_arns" {
  description = "OIDC IAM role ARNs by environment for GitHub Environment secrets."
  value       = try(module.oidc_iam[0].role_arns, {})

}

output "oidc_deploy_role_names" {
  description = "OIDC IAM role names by environment."
  value       = try(module.oidc_iam[0].role_names, {})
}

output "primary_eks_cluster_name" {
  description = "Primary EKS cluster name for deployment workflows."
  value       = module.primary_eks.cluster_name
}

output "secondary_eks_cluster_name" {
  description = "Secondary EKS cluster name when passive cluster is enabled."
  value       = try(module.secondary_eks[0].cluster_name, null)
}

output "github_ecr_role_arn" {

  value = module.github_ecr_role.role_arn
}

output "monitoring_prometheus_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID."
  value       = try(module.monitoring[0].prometheus_workspace_id, null)
}

output "monitoring_grafana_workspace_id" {
  description = "Amazon Managed Grafana workspace ID."
  value       = try(module.monitoring[0].grafana_workspace_id, null)
}

output "monitoring_prometheus_endpoint" {
  description = "Amazon Managed Prometheus endpoint."
  value       = try(module.monitoring[0].prometheus_endpoint, null)
}

output "monitoring_grafana_endpoint" {
  description = "Amazon Managed Grafana endpoint."
  value       = try(module.monitoring[0].grafana_endpoint, null)
}

output "route53_primary_health_check_id" {
  description = "Route53 health check ID used for failover from the primary region."
  value       = try(module.route53[0].primary_health_check_id, null)
}

output "primary_alb_dns_name" {
  description = "Primary region ALB DNS name."
  value       = aws_lb.primary.dns_name
}

output "primary_alb_zone_id" {
  description = "Primary region ALB zone ID."
  value       = aws_lb.primary.zone_id
}

output "secondary_alb_dns_name" {
  description = "Secondary region ALB DNS name."
  value       = try(aws_lb.secondary[0].dns_name, null)
}

output "secondary_alb_zone_id" {
  description = "Secondary region ALB zone ID."
  value       = try(aws_lb.secondary[0].zone_id, null)
}

output "primary_database_endpoint" {
  description = "Primary RDS database endpoint."
  value       = module.primary_database.db_instance_endpoint
}

output "secondary_database_endpoint" {
  description = "Secondary RDS database endpoint (read replica)."
  value       = try(module.secondary_database[0].db_instance_endpoint, null)
}

output "rds_failover_lambda_name" {
  description = "Lambda function name used to promote the secondary database."
  value       = try(module.rds_failover_automation[0].lambda_function_name, null)
}

output "rds_failover_event_topic_arn" {
  description = "SNS topic ARN used for RDS failover events."
  value       = try(module.rds_failover_automation[0].failover_event_topic_arn, null)
}

output "rds_replication_lag_alarm_name" {
  description = "CloudWatch alarm name for replica lag."
  value       = try(module.rds_failover_automation[0].replication_lag_alarm_name, null)
}

output "primary_database_arn" {
  description = "Primary RDS database ARN."
  value       = module.primary_database.db_instance_arn
}

output "route53_primary_fqdn" {
  description = "Primary DNS record FQDN."
  value       = try(module.route53[0].primary_fqdn, null)
}

output "route53_secondary_fqdn" {
  description = "Secondary DNS record FQDN."
  value       = try(module.route53[0].secondary_fqdn, null)
}

output "primary_postgres_endpoint" {
  value = module.primary_postgres_database.db_instance_endpoint
}
