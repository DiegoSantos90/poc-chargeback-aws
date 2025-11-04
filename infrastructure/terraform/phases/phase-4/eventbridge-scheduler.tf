# =============================================================================
# Phase 4 - EventBridge Scheduler
# =============================================================================
# This file creates EventBridge Schedulers to trigger the Glue ETL job
# multiple times per day (parametrized). For 4 executions/day, it creates
# 4 separate schedules at 00:30, 06:30, 12:30, 18:30.
# =============================================================================

# -----------------------------------------------------------------------------
# EventBridge Scheduler - Glue ETL Triggers
# -----------------------------------------------------------------------------
# Creates N schedules based on consolidation_executions_per_day
# Each schedule triggers at (hour * interval) + 30 minutes offset

resource "aws_scheduler_schedule" "glue_consolidation" {
  count = var.enable_scheduler ? var.consolidation_executions_per_day : 0
  
  name        = "${local.eventbridge_scheduler_name}-${count.index + 1}"
  description = "Triggers Glue consolidation job ${count.index + 1} of ${var.consolidation_executions_per_day} daily executions"
  
  # Flexible time window (job can start within 15-minute window)
  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 15
  }
  
  # Schedule expression (cron-based)
  # Example for 4 executions: 0:30, 6:30, 12:30, 18:30
  schedule_expression          = local.schedule_cron_expressions[count.index]
  schedule_expression_timezone = var.scheduler_timezone
  
  # Target: Glue StartJobRun API
  target {
    arn      = aws_glue_job.consolidation.arn
    role_arn = aws_iam_role.eventbridge_scheduler.arn
    
    # Input to Glue job (override default arguments)
    input = jsonencode({
      "--EXECUTION_TIME"     = "{{scheduledTime}}"
      "--EXECUTION_SEQUENCE" = count.index + 1
      "--TOTAL_EXECUTIONS"   = var.consolidation_executions_per_day
    })
    
    # Retry policy
    retry_policy {
      maximum_event_age_in_seconds = 3600     # 1 hour
      maximum_retry_attempts       = 2
    }
    
    # Dead-letter queue (optional, for failed invocations)
    # Uncomment if you want DLQ for debugging
    # dead_letter_config {
    #   arn = aws_sqs_queue.scheduler_dlq[0].arn
    # }
  }
  
  # State (enabled by default)
  state = "ENABLED"
  
  # Note: EventBridge Scheduler doesn't support tags directly
  # Use resource groups or tagging via AWS CLI if needed
  
  depends_on = [
    aws_glue_job.consolidation,
    aws_iam_role.eventbridge_scheduler
  ]
}

# -----------------------------------------------------------------------------
# SNS Topic for Scheduler Notifications (Optional)
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "scheduler_notifications" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? 1 : 0
  
  name         = "${local.eventbridge_scheduler_name}-notifications"
  display_name = "EventBridge Scheduler Notifications"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.eventbridge_scheduler_name}-notifications"
    }
  )
}

resource "aws_sns_topic_subscription" "scheduler_email" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? length(var.alarm_email_endpoints) : 0
  
  topic_arn = aws_sns_topic.scheduler_notifications[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email_endpoints[count.index]
}

# -----------------------------------------------------------------------------
# CloudWatch Event Rule for Scheduler Failures (Optional)
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "scheduler_failures" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  name        = "${local.eventbridge_scheduler_name}-failures"
  description = "Capture EventBridge Scheduler failures"
  
  event_pattern = jsonencode({
    source      = ["aws.scheduler"]
    detail-type = ["Scheduler Target Invocation Failed"]
    detail = {
      scheduleName = [for schedule in aws_scheduler_schedule.glue_consolidation : schedule.name]
    }
  })
}

resource "aws_cloudwatch_event_target" "scheduler_failures_sns" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? 1 : 0
  
  rule      = aws_cloudwatch_event_rule.scheduler_failures[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.scheduler_notifications[0].arn
}

# SNS topic policy to allow EventBridge to publish
resource "aws_sns_topic_policy" "scheduler_notifications" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? 1 : 0
  
  arn    = aws_sns_topic.scheduler_notifications[0].arn
  policy = data.aws_iam_policy_document.scheduler_sns_policy[0].json
}

data "aws_iam_policy_document" "scheduler_sns_policy" {
  count = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? 1 : 0
  
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.scheduler_notifications[0].arn]
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "scheduler_names" {
  description = "Names of the EventBridge schedulers"
  value       = var.enable_scheduler ? aws_scheduler_schedule.glue_consolidation[*].name : []
}

output "scheduler_arns" {
  description = "ARNs of the EventBridge schedulers"
  value       = var.enable_scheduler ? aws_scheduler_schedule.glue_consolidation[*].arn : []
}

output "scheduler_expressions" {
  description = "Cron expressions for each scheduler"
  value       = var.enable_scheduler ? local.schedule_cron_expressions : []
}

output "scheduler_times_local" {
  description = "Execution times in local timezone"
  value = var.enable_scheduler ? [
    for i in range(var.consolidation_executions_per_day) :
    format("%02d:30 %s", i * local.schedule_interval_hours, var.scheduler_timezone)
  ] : []
}
