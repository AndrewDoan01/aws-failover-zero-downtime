output "alarm_topic_arn" {
  description = "ARN of the SNS topic receiving monitoring alerts."
  value       = aws_sns_topic.alerts.arn
}

output "prometheus_workspace_id" {
  description = "Amazon Managed Prometheus workspace ID."
  value       = try(aws_prometheus_workspace.this[0].id, null)
}

output "prometheus_workspace_arn" {
  description = "Amazon Managed Prometheus workspace ARN."
  value       = try(aws_prometheus_workspace.this[0].arn, null)
}

output "prometheus_endpoint" {
  description = "Amazon Managed Prometheus ingest/query endpoint."
  value       = try(aws_prometheus_workspace.this[0].prometheus_endpoint, null)
}

output "grafana_workspace_id" {
  description = "Amazon Managed Grafana workspace ID."
  value       = try(aws_grafana_workspace.this[0].id, null)
}

output "grafana_workspace_arn" {
  description = "Amazon Managed Grafana workspace ARN."
  value       = try(aws_grafana_workspace.this[0].arn, null)
}

output "grafana_endpoint" {
  description = "Amazon Managed Grafana workspace endpoint."
  value       = try(aws_grafana_workspace.this[0].endpoint, null)
}

output "rds_cpu_alarm_name" {
  description = "Name of the RDS CPU alarm when created."
  value       = try(aws_cloudwatch_metric_alarm.rds_cpu_high[0].alarm_name, null)
}

output "eks_failed_requests_alarm_name" {
  description = "Name of the EKS failed requests alarm when created."
  value       = try(aws_cloudwatch_metric_alarm.eks_failed_requests[0].alarm_name, null)
}
