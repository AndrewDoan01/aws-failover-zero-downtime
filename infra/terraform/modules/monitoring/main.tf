terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

locals {
  # Use a stable alias unless the caller overrides it.
  prometheus_workspace_alias = length(trimspace(var.prometheus_workspace_alias)) > 0 ? var.prometheus_workspace_alias : "${var.project_name}-amp"
}

# Allow Grafana to query metrics from the Prometheus workspace.
data "aws_iam_policy_document" "grafana_prometheus_access" {
  count = var.create_prometheus_workspace && var.create_grafana_workspace ? 1 : 0

  statement {
    sid    = "GrafanaQueryAccess"
    effect = "Allow"

    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries"
    ]

    resources = [
      aws_prometheus_workspace.this[0].arn
    ]

    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
  }
}

# Create the managed Prometheus workspace and optionally wire query logging.
resource "aws_prometheus_workspace" "this" {
  count = var.create_prometheus_workspace ? 1 : 0

  alias       = local.prometheus_workspace_alias
  kms_key_arn = null

  dynamic "logging_configuration" {
    for_each = length(trimspace(var.prometheus_logging_group_arn)) > 0 ? [1] : []

    content {
      log_group_arn = "${var.prometheus_logging_group_arn}:*"
    }
  }

  tags = var.tags
}

# Grant Grafana read access to the Prometheus workspace when both are enabled.
resource "null_resource" "grafana_prometheus_policy" {
  count = var.create_prometheus_workspace && var.create_grafana_workspace ? 1 : 0

  triggers = {
    workspace_id = aws_prometheus_workspace.this[0].id
    policy       = data.aws_iam_policy_document.grafana_prometheus_access[0].json
  }

  provisioner "local-exec" {
    when    = create
    command = "aws amp put-resource-policy --workspace-id ${self.triggers.workspace_id} --policy '${self.triggers.policy}'"
  }
}

# Create the managed Grafana workspace with Prometheus and CloudWatch enabled.
resource "aws_grafana_workspace" "this" {
  count = var.create_grafana_workspace ? 1 : 0

  account_access_type      = var.grafana_account_access_type
  authentication_providers = var.grafana_authentication_providers
  permission_type          = var.grafana_permission_type
  data_sources             = var.grafana_data_sources
  description              = var.grafana_description
  tags                     = var.tags
}

# Centralize operational alerts in SNS for downstream notifications.
resource "aws_sns_topic" "alerts" {
  name = var.alarm_topic_name
  tags = var.tags
}

# Alert when RDS CPU crosses the configured threshold.
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.create_rds_cpu_alarm ? 1 : 0

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

# Alert when the EKS control plane reports failed requests.
resource "aws_cloudwatch_metric_alarm" "eks_failed_requests" {
  count = var.create_eks_failed_requests_alarm ? 1 : 0

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
