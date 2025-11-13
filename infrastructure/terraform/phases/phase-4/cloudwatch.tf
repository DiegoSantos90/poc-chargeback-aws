# =============================================================================
# Phase 4 - CloudWatch Monitoring and Alarms
# =============================================================================
# This file creates CloudWatch resources for monitoring Glue jobs:
# 1. SNS topic for alerts
# 2. Alarms for job failures and performance issues
# 3. Dashboard for visualizing metrics
# =============================================================================

# -----------------------------------------------------------------------------
# SNS Topic for Glue Alerts
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "glue_alerts" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? 1 : 0
  
  name         = local.sns_topic_name
  display_name = "Glue ETL Job Alerts"
  
  tags = merge(
    local.common_tags,
    {
      Name = local.sns_topic_name
    }
  )
}

# SNS topic policy (allow CloudWatch to publish)
resource "aws_sns_topic_policy" "glue_alerts" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? 1 : 0
  
  arn    = aws_sns_topic.glue_alerts[0].arn
  policy = data.aws_iam_policy_document.sns_topic_policy[0].json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? 1 : 0
  
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.glue_alerts[0].arn]
  }
}

# Email subscriptions
resource "aws_sns_topic_subscription" "glue_alert_emails" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? length(var.alarm_email_endpoints) : 0
  
  topic_arn = aws_sns_topic.glue_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoints[count.index]
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard - Glue Job Metrics
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "glue_consolidation" {
  dashboard_name = "${local.name_prefix}-glue-consolidation"
  
  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: Job Run Status
      {
        type = "metric"
        properties = {
          metrics = [
            ["Glue", "glue.driver.aggregate.numCompletedStages", { "stat" = "Sum", "label" = "Completed Stages" }],
            [".", "glue.driver.aggregate.numFailedStages", { "stat" = "Sum", "label" = "Failed Stages" }],
            [".", "glue.driver.aggregate.numCompletedTasks", { "stat" = "Sum", "label" = "Completed Tasks" }],
            [".", "glue.driver.aggregate.numFailedTasks", { "stat" = "Sum", "label" = "Failed Tasks" }]
          ]
          view    = "timeSeries"
          region  = local.region
          title   = "Glue Job Execution Status"
          period  = 300
          stacked = false
        }
      },
      
      # Widget 2: Execution Time
      {
        type = "metric"
        properties = {
          metrics = [
            ["Glue", "glue.driver.aggregate.elapsedTime", { "stat" = "Average", "label" = "Avg Execution Time (ms)" }],
            ["...", { "stat" = "Maximum", "label" = "Max Execution Time (ms)" }]
          ]
          view   = "timeSeries"
          region = local.region
          title  = "Job Execution Time"
          period = 300
          yAxis = {
            left = {
              label = "Milliseconds"
            }
          }
        }
      },
      
      # Widget 3: Data Processed
      {
        type = "metric"
        properties = {
          metrics = [
            ["Glue", "glue.driver.aggregate.recordsRead", { "stat" = "Sum", "label" = "Records Read" }],
            [".", "glue.driver.aggregate.recordsWritten", { "stat" = "Sum", "label" = "Records Written" }],
            [".", "glue.driver.aggregate.bytesRead", { "stat" = "Sum", "label" = "Bytes Read" }],
            [".", "glue.driver.aggregate.bytesWritten", { "stat" = "Sum", "label" = "Bytes Written" }]
          ]
          view   = "timeSeries"
          region = local.region
          title  = "Data Processing Metrics"
          period = 300
        }
      },
      
      # Widget 4: Resource Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["Glue", "glue.driver.system.cpuSystemLoad", { "stat" = "Average", "label" = "CPU Load" }],
            [".", "glue.driver.jvm.heap.used", { "stat" = "Average", "label" = "Heap Memory Used" }],
            [".", "glue.driver.BlockManager.disk.diskSpaceUsed_MB", { "stat" = "Average", "label" = "Disk Used (MB)" }]
          ]
          view   = "timeSeries"
          region = local.region
          title  = "Resource Utilization"
          period = 300
        }
      },
      
      # Widget 5: Crawler Status
      {
        type = "log"
        properties = {
          query = <<-EOQ
            SOURCE '${local.glue_crawler_log_group}'
            | fields @timestamp, @message
            | filter @message like /Crawler started/
              or @message like /Crawler stopped/
              or @message like /ERROR/
            | sort @timestamp desc
            | limit 20
          EOQ
          region = local.region
          title  = "Crawler Activity (Last 20 Events)"
        }
      },
      
      # Widget 6: Job Logs
      {
        type = "log"
        properties = {
          query = <<-EOQ
            SOURCE '${local.glue_job_log_group}'
            | fields @timestamp, @message
            | filter @message like /ERROR/
              or @message like /Exception/
              or @message like /Starting/
              or @message like /Completed/
            | sort @timestamp desc
            | limit 20
          EOQ
          region = local.region
          title  = "Job Errors and Key Events (Last 20)"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Additional Custom Metrics (via Logs Insights)
# -----------------------------------------------------------------------------

# Metric Filter: Count successful job completions
resource "aws_cloudwatch_log_metric_filter" "job_success" {
  name           = "${local.glue_job_name}-success-count"
  log_group_name = local.glue_job_log_group
  pattern        = "[time, request_id, level = INFO*, msg = *Consolidation*completed*successfully*]"
  
  metric_transformation {
    name      = "GlueJobSuccessCount"
    namespace = "CustomGlue/${local.name_prefix}"
    value     = "1"
    unit      = "Count"
  }
  
  depends_on = [aws_cloudwatch_log_group.glue_job]
}

# Metric Filter: Count job failures
resource "aws_cloudwatch_log_metric_filter" "job_failure" {
  name           = "${local.glue_job_name}-failure-count"
  log_group_name = local.glue_job_log_group
  pattern        = "[time, request_id, level = ERROR*, ...]"
  
  metric_transformation {
    name      = "GlueJobFailureCount"
    namespace = "CustomGlue/${local.name_prefix}"
    value     = "1"
    unit      = "Count"
  }
  
  depends_on = [aws_cloudwatch_log_group.glue_job]
}

# Metric Filter: Track records processed
resource "aws_cloudwatch_log_metric_filter" "records_processed" {
  name           = "${local.glue_job_name}-records-processed"
  log_group_name = local.glue_job_log_group
  pattern        = "[time, request_id, level, msg, records_processed]"
  
  metric_transformation {
    name      = "RecordsProcessed"
    namespace = "CustomGlue/${local.name_prefix}"
    value     = "$records_processed"
    unit      = "Count"
  }
  
  depends_on = [aws_cloudwatch_log_group.glue_job]
}

# -----------------------------------------------------------------------------
# Alarm: Daily Success Rate
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "daily_success_rate" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.glue_job_name}-daily-success-rate"
  alarm_description   = "Alert when daily Glue job success rate drops below threshold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = var.consolidation_executions_per_day * 0.75 # 75% success rate
  treat_missing_data  = "breaching"
  
  metric_query {
    id          = "success_rate"
    expression  = "success / (success + failure)"
    label       = "Success Rate"
    return_data = true
  }
  
  metric_query {
    id = "success"
    metric {
      metric_name = "GlueJobSuccessCount"
      namespace   = "CustomGlue/${local.name_prefix}"
      period      = 86400 # 1 day
      stat        = "Sum"
    }
  }
  
  metric_query {
    id = "failure"
    metric {
      metric_name = "GlueJobFailureCount"
      namespace   = "CustomGlue/${local.name_prefix}"
      period      = 86400 # 1 day
      stat        = "Sum"
    }
  }
  
  alarm_actions = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.glue_alerts[0].arn] : []
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.glue_job_name}-success-rate-alarm"
    }
  )
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.glue_consolidation.dashboard_name
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.glue_consolidation.dashboard_name}"
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? aws_sns_topic.glue_alerts[0].arn : null
}

output "alarm_endpoints" {
  description = "Email endpoints configured for alarms"
  value       = var.alarm_email_endpoints
  sensitive   = true
}
