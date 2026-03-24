output "alarm_topic_arn" {
  description = "ARN of the SNS topic receiving monitoring alerts."
  value       = aws_sns_topic.alerts.arn
}

output "rds_cpu_alarm_name" {
  description = "Name of the RDS CPU alarm when created."
  value       = try(aws_cloudwatch_metric_alarm.rds_cpu_high[0].alarm_name, null)
}

output "eks_failed_requests_alarm_name" {
  description = "Name of the EKS failed requests alarm when created."
  value       = try(aws_cloudwatch_metric_alarm.eks_failed_requests[0].alarm_name, null)
}
