resource "aws_sns_topic" "alerts" {
  name = var.alarm_topic_name
  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.rds_instance_id == null ? 0 : 1

  alarm_name          = "${var.project_name}-rds-cpu-high"
  alarm_description   = "High CPU utilization on RDS instance"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.cpu_alarm_threshold
  evaluation_periods  = var.evaluation_periods
  period              = var.period
  statistic           = "Average"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "eks_failed_requests" {
  count = var.eks_cluster_name == null ? 0 : 1

  alarm_name          = "${var.project_name}-eks-failed-requests"
  alarm_description   = "Failed API server requests on EKS cluster"
  namespace           = "AWS/EKS"
  metric_name         = "cluster_failed_request_count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 1
  period              = 300
  statistic           = "Sum"

  dimensions = {
    ClusterName = var.eks_cluster_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}
