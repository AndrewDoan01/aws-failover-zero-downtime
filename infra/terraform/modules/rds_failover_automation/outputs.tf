output "failover_event_topic_arn" {
  description = "SNS topic ARN used for primary DB failover events."
  value       = aws_sns_topic.failover_events.arn
}

output "replication_alarm_topic_arn" {
  description = "SNS topic ARN receiving replication lag alarms."
  value       = aws_sns_topic.alarm_topic.arn
}

output "lambda_function_name" {
  description = "Lambda function name that promotes the read replica."
  value       = aws_lambda_function.promote_replica.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN that promotes the read replica."
  value       = aws_lambda_function.promote_replica.arn
}

output "replication_lag_alarm_name" {
  description = "CloudWatch alarm name for replication lag."
  value       = try(aws_cloudwatch_metric_alarm.replication_lag[0].alarm_name, null)
}

output "primary_event_subscription_id" {
  description = "RDS event subscription ID that feeds the failover Lambda."
  value       = aws_db_event_subscription.primary_failover.id
}
