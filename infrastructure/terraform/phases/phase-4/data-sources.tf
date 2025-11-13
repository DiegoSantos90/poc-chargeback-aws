# =============================================================================
# Phase 4 - Data Sources (Import Phase 1 Outputs)
# =============================================================================
# This file imports outputs from Phase 1 that are needed for Phase 4.
# Phase 4 needs: S3 Parquet Bucket (for landing and consolidated data)
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Account and Region Information
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Local Variables for Resource Naming and Configuration
# -----------------------------------------------------------------------------

locals {
  # Account and region info
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
  
  # Naming convention: {project}-{environment}-{resource}
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags for all Phase 4 resources
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Phase       = "4"
      ManagedBy   = "Terraform"
      Purpose     = "Data-Consolidation"
      Component   = "Glue-ETL"
    },
    var.tags
  )
  
  # Resource-specific naming
  glue_database_name        = "${local.name_prefix}-${var.glue_database_name}"
  glue_crawler_name         = "${local.name_prefix}-${var.glue_crawler_name}"
  glue_job_name             = "${local.name_prefix}-${var.glue_job_name}"
  glue_iam_role_name        = "${local.name_prefix}-glue-role"
  eventbridge_scheduler_name = "${local.name_prefix}-consolidation-scheduler"
  sns_topic_name            = "${local.name_prefix}-glue-alerts"
  
  # CloudWatch Log Groups
  glue_crawler_log_group = "/aws-glue/crawlers/${local.glue_crawler_name}"
  glue_job_log_group     = "/aws-glue/jobs/${local.glue_job_name}"
  
  # S3 paths (full URIs)
  landing_zone_s3_path    = "s3://${var.parquet_bucket_name}/${var.s3_landing_prefix}/"
  consolidated_s3_path    = "s3://${var.parquet_bucket_name}/${var.s3_consolidated_prefix}/"
  glue_scripts_s3_path    = "s3://${var.parquet_bucket_name}/${var.s3_glue_scripts_prefix}/"
  glue_temp_s3_path       = "s3://${var.parquet_bucket_name}/${var.s3_glue_temp_prefix}/"
  glue_spark_logs_s3_path = "s3://${var.parquet_bucket_name}/${var.s3_glue_spark_logs_prefix}/"
  
  # Glue Catalog table names
  landing_table_name     = "${var.glue_crawler_table_prefix}chargebacks"
  consolidated_table_name = "chargebacks_consolidated"
  
  # EventBridge schedule configuration
  schedule_interval_hours = 24 / var.consolidation_executions_per_day
  
  # Generate cron expressions for each execution time
  # Format: cron(Minutes Hours Day-of-month Month Day-of-week Year)
  # Example for 4 executions: 0:30, 6:30, 12:30, 18:30
  schedule_cron_expressions = [
    for i in range(var.consolidation_executions_per_day) :
    "cron(30 ${i * local.schedule_interval_hours} * * ? *)"
  ]
  
  # Calculate expected data volumes (for cost estimation)
  daily_chargebacks       = 5000000 # 5M target
  records_per_execution   = local.daily_chargebacks / var.consolidation_executions_per_day
  records_per_file        = local.records_per_execution / var.consolidation_output_files
  avg_record_size_bytes   = 100 # Estimated after compression
  file_size_mb            = (local.records_per_file * local.avg_record_size_bytes) / 1024 / 1024
  
  # Kafka/MSK configuration
  # Note: Use only var.enable_kafka_notifications to avoid dependency on Phase 3 outputs during plan
  kafka_enabled = var.enable_kafka_notifications
  
  # Glue job arguments (passed to PySpark script)
  default_glue_job_arguments = {
    "--job-language"                     = "python"
    "--TempDir"                          = local.glue_temp_s3_path
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = local.glue_spark_logs_s3_path
    
    # Custom arguments for consolidation script
    "--SOURCE_DATABASE"         = local.glue_database_name
    "--SOURCE_TABLE"            = local.landing_table_name
    "--OUTPUT_PATH"             = local.consolidated_s3_path
    "--OUTPUT_FILE_COUNT"       = tostring(var.consolidation_output_files)
    "--OUTPUT_FORMAT"           = var.output_format
    "--CSV_DELIMITER"           = var.csv_delimiter
    "--CSV_HEADER"              = tostring(var.csv_header)
    "--CSV_QUOTE_CHAR"          = var.csv_quote_char
    "--COMPRESSION_CODEC"       = var.parquet_compression_codec
    "--EXECUTION_TIME"          = "runtime" # Will be replaced by EventBridge
    "--ENABLE_PARTITION_FILTER" = "true"
    "--ENABLE_KAFKA"            = tostring(local.kafka_enabled)
    "--KAFKA_BOOTSTRAP_SERVERS" = var.msk_bootstrap_brokers
    "--KAFKA_TOPIC"             = var.kafka_consolidation_topic
  }
  
  # Merge custom arguments
  glue_job_arguments = merge(
    local.default_glue_job_arguments,
    var.glue_job_arguments
  )
}

# -----------------------------------------------------------------------------
# Data Source: Glue Script (for ETL job)
# -----------------------------------------------------------------------------

# Path to the PySpark script in the repository
locals {
  glue_script_local_path = "${path.module}/../../../../deployments/glue-jobs/consolidate_chargebacks.py"
  glue_script_s3_key     = "${var.s3_glue_scripts_prefix}/consolidate_chargebacks.py"
}

# -----------------------------------------------------------------------------
# Outputs for Internal Use
# -----------------------------------------------------------------------------

output "account_id" {
  description = "AWS Account ID"
  value       = local.account_id
}

output "region" {
  description = "AWS Region"
  value       = local.region
}

output "name_prefix" {
  description = "Common naming prefix for resources"
  value       = local.name_prefix
}

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

output "s3_paths" {
  description = "S3 paths used by Glue"
  value = {
    landing_zone    = local.landing_zone_s3_path
    consolidated    = local.consolidated_s3_path
    glue_scripts    = local.glue_scripts_s3_path
    glue_temp       = local.glue_temp_s3_path
    glue_spark_logs = local.glue_spark_logs_s3_path
  }
}

output "data_volume_estimates" {
  description = "Estimated data volumes for cost planning"
  value = {
    daily_chargebacks     = local.daily_chargebacks
    records_per_execution = local.records_per_execution
    records_per_file      = local.records_per_file
    file_size_mb          = local.file_size_mb
    executions_per_day    = var.consolidation_executions_per_day
  }
}
