# =============================================================================
# Phase 3 - CloudWatch Monitoring
# =============================================================================
# This file creates CloudWatch resources for monitoring Phase 3 components:
# - Lambda stream processor logs and metrics
# - MSK cluster metrics
# - Kinesis Data Analytics (Flink) logs and metrics
# - Alarms for critical failures
# =============================================================================

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------

# Lambda Stream Processor Logs
resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.lambda_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = local.lambda_log_group_name
    }
  )
}

# Kinesis Data Analytics (Flink) Logs
resource "aws_cloudwatch_log_group" "flink" {
  name              = local.flink_log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = local.flink_log_group_name
    }
  )
}

# Flink Log Stream
resource "aws_cloudwatch_log_stream" "flink" {
  name           = "application-log-stream"
  log_group_name = aws_cloudwatch_log_group.flink.name
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms - Lambda
# -----------------------------------------------------------------------------

# Lambda Errors Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.lambda_function_name}-errors"
  alarm_description   = "Lambda stream processor error rate is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.stream_processor.function_name
  }

  alarm_actions = var.alarm_email_endpoint != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# Lambda Throttles Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.lambda_function_name}-throttles"
  alarm_description   = "Lambda stream processor is being throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.stream_processor.function_name
  }

  alarm_actions = var.alarm_email_endpoint != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.lambda_function_name}-duration"
  alarm_description   = "Lambda execution duration approaching timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = var.lambda_timeout * 1000 * 0.8 # 80% of timeout (in milliseconds)
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.stream_processor.function_name
  }

  alarm_actions = var.alarm_email_endpoint != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms - MSK
# -----------------------------------------------------------------------------

# MSK Cluster CPU Utilization (Note: Limited metrics for Serverless)
resource "aws_cloudwatch_metric_alarm" "msk_active_connection_count" {
  count = var.enable_msk_monitoring ? 1 : 0

  alarm_name          = "${local.msk_cluster_name}-active-connections"
  alarm_description   = "MSK active connection count is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ClientConnectionCount"
  namespace           = "AWS/Kafka"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "notBreaching"

  dimensions = {
    "Cluster Name" = aws_msk_serverless_cluster.main.cluster_name
  }

  alarm_actions = var.alarm_email_endpoint != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms - Kinesis Data Analytics (Flink)
# -----------------------------------------------------------------------------

# Flink Downtime Alarm
resource "aws_cloudwatch_metric_alarm" "flink_downtime" {
  alarm_name          = "${local.flink_application_name}-downtime"
  alarm_description   = "Flink application is down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "uptime"
  namespace           = "AWS/KinesisAnalytics"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    Application = aws_kinesisanalyticsv2_application.flink_parquet_writer.name
  }

  alarm_actions = var.alarm_email_endpoint != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# Flink Checkpoint Failures
resource "aws_cloudwatch_metric_alarm" "flink_checkpoint_failures" {
  count = var.flink_checkpointing_enabled ? 1 : 0

  alarm_name          = "${local.flink_application_name}-checkpoint-failures"
  alarm_description   = "Flink application checkpoint failures detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "numFailedCheckpoints"
  namespace           = "AWS/KinesisAnalytics"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"

  dimensions = {
    Application = aws_kinesisanalyticsv2_application.flink_parquet_writer.name
  }

  alarm_actions = var.alarm_email_endpoint != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# Flink Backpressure (indicates bottleneck)
resource "aws_cloudwatch_metric_alarm" "flink_backpressure" {
  count = var.enable_flink_metrics ? 1 : 0

  alarm_name          = "${local.flink_application_name}-backpressure"
  alarm_description   = "Flink application experiencing backpressure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "backPressuredTimeMsPerSecond"
  namespace           = "AWS/KinesisAnalytics"
  period              = 60
  statistic           = "Average"
  threshold           = 500 # 50% of time backpressured
  treat_missing_data  = "notBreaching"

  dimensions = {
    Application = aws_kinesisanalyticsv2_application.flink_parquet_writer.name
  }

  alarm_actions = var.alarm_email_endpoint != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# SNS Topic for Alarms (Optional)
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "alarms" {
  count = var.alarm_email_endpoint != "" ? 1 : 0

  name = "${local.name_prefix}-phase3-alarms"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-phase3-alarms"
    }
  )
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count = var.alarm_email_endpoint != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoint
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "phase3" {
  dashboard_name = "${local.name_prefix}-phase3-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Lambda Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Invocations" }],
            [".", "Errors", { stat = "Sum", label = "Errors" }],
            [".", "Throttles", { stat = "Sum", label = "Throttles" }],
            [".", "Duration", { stat = "Average", label = "Avg Duration" }]
          ]
          period = 300
          stat   = "Sum"
          region = local.region
          title  = "Lambda Stream Processor"
          dimensions = {
            FunctionName = [aws_lambda_function.stream_processor.function_name]
          }
        }
      },
      # MSK Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Kafka", "ClientConnectionCount", { stat = "Average", label = "Connections" }],
            [".", "BytesInPerSec", { stat = "Sum", label = "Bytes In/Sec" }],
            [".", "BytesOutPerSec", { stat = "Sum", label = "Bytes Out/Sec" }]
          ]
          period = 300
          stat   = "Average"
          region = local.region
          title  = "MSK Cluster"
          dimensions = {
            "Cluster Name" = [aws_msk_serverless_cluster.main.cluster_name]
          }
        }
      },
      # Flink Metrics
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/KinesisAnalytics", "KPUs", { stat = "Average", label = "KPUs Used" }],
            [".", "uptime", { stat = "Average", label = "Uptime" }],
            [".", "numRecordsInPerSecond", { stat = "Sum", label = "Records/Sec" }]
          ]
          period = 300
          stat   = "Average"
          region = local.region
          title  = "Flink Application"
          dimensions = {
            Application = [aws_kinesisanalyticsv2_application.flink_parquet_writer.name]
          }
        }
      },
      # Log Insights Query Widget
      {
        type = "log"
        properties = {
          query   = <<-EOT
            SOURCE '${local.lambda_log_group_name}'
            | fields @timestamp, @message
            | filter @message like /ERROR/
            | sort @timestamp desc
            | limit 20
          EOT
          region  = local.region
          title   = "Lambda Errors (Last 20)"
        }
      }
    ]
  })

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_cloudwatch_log_group.flink
  ]
}
