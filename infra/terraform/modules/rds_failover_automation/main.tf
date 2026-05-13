terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.secondary]
    }
    archive = {
      source = "hashicorp/archive"
    }
  }
}

locals {
  failover_event_topic_name = "${var.project_name}-rds-failover-events"
  replication_alarm_name    = "${var.project_name}-rds-replication-lag-high"
  alarm_topic_name          = "${var.project_name}-rds-replication-alerts"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "RdsFailoverControl"
    effect = "Allow"

    actions = [
      "rds:DescribeDBInstances",
      "rds:PromoteReadReplica"
    ]

    resources = ["*"]
  }
}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/lambda_failover.py"
  output_path = "${path.module}/lambda_failover.zip"
}

resource "aws_sns_topic" "failover_events" {
  name = local.failover_event_topic_name

  tags = var.tags
}

resource "aws_sns_topic" "alarm_topic" {
  provider = aws.secondary

  name = local.alarm_topic_name

  tags = var.tags
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-rds-failover-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_rds" {
  name   = "${var.project_name}-rds-failover-lambda-rds"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_lambda_function" "promote_replica" {
  function_name = "${var.project_name}-rds-promote-replica"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_failover.handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  environment {
    variables = {
      PRIMARY_DB_IDENTIFIER   = var.primary_db_identifier
      SECONDARY_DB_IDENTIFIER = var.secondary_db_identifier
      SECONDARY_REGION        = var.secondary_region
      BACKUP_RETENTION_DAYS   = tostring(var.promoted_backup_retention_days)
      DRY_RUN                 = tostring(var.enable_dry_run)
    }
  }

  tags = var.tags
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.failover_events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.promote_replica.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNSTopic"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.promote_replica.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.failover_events.arn
}

resource "aws_db_event_subscription" "primary_failover" {
  name      = "${var.project_name}-primary-db-events"
  sns_topic = aws_sns_topic.failover_events.arn

  source_type = "db-instance"
  source_ids  = [var.primary_db_identifier]

  event_categories = var.rds_event_categories
  enabled          = true
}

resource "aws_cloudwatch_metric_alarm" "replication_lag" {
  provider = aws.secondary

  count = var.create_replication_lag_alarm ? 1 : 0

  alarm_name          = local.replication_alarm_name
  alarm_description   = "Replication lag is above the configured threshold on the secondary RDS instance"
  namespace           = "AWS/RDS"
  metric_name         = "ReplicaLag"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.replication_lag_threshold_seconds
  evaluation_periods  = var.replication_lag_evaluation_periods
  period              = var.replication_lag_period
  statistic           = "Average"
  treat_missing_data  = "missing"

  dimensions = {
    DBInstanceIdentifier = var.secondary_db_identifier
  }

  alarm_actions = [aws_sns_topic.alarm_topic.arn]
  ok_actions    = [aws_sns_topic.alarm_topic.arn]

  tags = var.tags
}
