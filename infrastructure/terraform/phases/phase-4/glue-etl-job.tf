# =============================================================================
# Phase 4 - AWS Glue ETL Job
# =============================================================================
# This file creates the Glue ETL job that consolidates thousands of small
# Parquet files from the landing zone into optimized, partitioned datasets.
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Object - Upload Glue Script
# -----------------------------------------------------------------------------

resource "aws_s3_object" "glue_script" {
  bucket = var.parquet_bucket_name
  key    = local.glue_script_s3_key
  source = local.glue_script_local_path
  etag   = filemd5(local.glue_script_local_path)
  
  tags = merge(
    local.common_tags,
    {
      Name = "Glue ETL Script - Consolidation"
    }
  )
  
  # Only upload if script exists
  lifecycle {
    precondition {
      condition     = fileexists(local.glue_script_local_path)
      error_message = "Glue script not found at ${local.glue_script_local_path}"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Glue Job - Data Consolidation
# -----------------------------------------------------------------------------

resource "aws_glue_job" "consolidation" {
  name     = local.glue_job_name
  role_arn = aws_iam_role.glue.arn
  
  description = "Consolidates landing zone Parquet files into optimized datasets (${var.consolidation_output_files} files per execution)"
  
  # Glue version (3.0 = Spark 3.1, Python 3.7, supports latest features)
  glue_version = "3.0"
  
  # Worker configuration (for 5M chargebacks/day)
  worker_type       = var.glue_job_worker_type
  number_of_workers = var.glue_job_number_of_workers
  
  # Timeout and retry configuration
  timeout        = var.glue_job_timeout
  max_retries    = var.glue_job_max_retries
  max_capacity   = null # Use worker_type instead of deprecated max_capacity
  
  # Execution limits
  execution_property {
    max_concurrent_runs = var.glue_job_max_concurrent_runs
  }
  
  # Script location
  command {
    name            = "glueetl"
    script_location = "s3://${var.parquet_bucket_name}/${local.glue_script_s3_key}"
    python_version  = "3"
  }
  
  # Glue connection for MSK access (if Kafka enabled)
  connections = local.kafka_enabled && length(var.private_subnet_ids) > 0 ? [aws_glue_connection.msk[0].name] : []
  
  # Default arguments (passed to PySpark script)
  default_arguments = local.glue_job_arguments
  
  tags = merge(
    local.common_tags,
    {
      Name = local.glue_job_name
    }
  )
  
  # Ensure script is uploaded and IAM role exists
  depends_on = [
    aws_s3_object.glue_script,
    aws_iam_role_policy_attachment.glue_service_policy,
    aws_iam_role_policy.glue_s3_access,
    aws_iam_role_policy.glue_catalog_access
  ]
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for Glue Job
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "glue_job" {
  name              = local.glue_job_log_group
  retention_in_days = 7 # Keep logs for 7 days
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.glue_job_name}-logs"
    }
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms for Glue Job
# -----------------------------------------------------------------------------

# Alarm: Job Failed
resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.glue_job_name}-failure"
  alarm_description   = "Glue consolidation job failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "Glue"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    JobName = local.glue_job_name
    Type    = "count"
  }
  
  alarm_actions = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.glue_alerts[0].arn] : []
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.glue_job_name}-failure-alarm"
    }
  )
}

# Alarm: Job Timeout
resource "aws_cloudwatch_metric_alarm" "glue_job_timeout" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.glue_job_name}-timeout"
  alarm_description   = "Glue consolidation job exceeded expected duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "glue.driver.aggregate.elapsedTime"
  namespace           = "Glue"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1800000 # 30 minutes in milliseconds
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    JobName = local.glue_job_name
    Type    = "gauge"
  }
  
  alarm_actions = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.glue_alerts[0].arn] : []
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.glue_job_name}-timeout-alarm"
    }
  )
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "glue_job_name" {
  description = "Name of the Glue ETL job"
  value       = aws_glue_job.consolidation.name
}

output "glue_job_arn" {
  description = "ARN of the Glue ETL job"
  value       = aws_glue_job.consolidation.arn
}

output "glue_job_script_location" {
  description = "S3 location of the Glue job script"
  value       = aws_glue_job.consolidation.command[0].script_location
}

output "glue_job_configuration" {
  description = "Glue job configuration summary"
  value = {
    worker_type       = aws_glue_job.consolidation.worker_type
    number_of_workers = aws_glue_job.consolidation.number_of_workers
    timeout_minutes   = aws_glue_job.consolidation.timeout
    max_retries       = aws_glue_job.consolidation.max_retries
    glue_version      = aws_glue_job.consolidation.glue_version
  }
}
