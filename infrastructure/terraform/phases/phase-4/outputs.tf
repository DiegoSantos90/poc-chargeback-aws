# =============================================================================
# Phase 4 - Terraform Outputs
# =============================================================================
# This file exports important values from Phase 4 for:
# 1. Verification and testing
# 2. Integration with other systems
# 3. Operational monitoring
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Glue Database and Catalog Outputs
# -----------------------------------------------------------------------------

output "glue_database" {
  description = "Glue database information"
  value = {
    name        = aws_glue_catalog_database.chargeback_data.name
    arn         = aws_glue_catalog_database.chargeback_data.arn
    catalog_id  = aws_glue_catalog_database.chargeback_data.catalog_id
    description = aws_glue_catalog_database.chargeback_data.description
  }
}

output "glue_tables" {
  description = "Glue table information"
  value = {
    landing_table = {
      name        = local.landing_table_name
      description = "Auto-created by crawler from landing zone files"
    }
    consolidated_table = {
      name        = aws_glue_catalog_table.chargebacks_consolidated.name
      description = aws_glue_catalog_table.chargebacks_consolidated.description
      location    = aws_glue_catalog_table.chargebacks_consolidated.storage_descriptor[0].location
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Glue Crawler Outputs
# -----------------------------------------------------------------------------

output "glue_crawler" {
  description = "Glue crawler information"
  value = {
    name     = aws_glue_crawler.landing_zone.name
    arn      = aws_glue_crawler.landing_zone.arn
    schedule = aws_glue_crawler.landing_zone.schedule
    state    = "Configured - Use AWS Console or CLI to check run status"
  }
}

# -----------------------------------------------------------------------------
# AWS Glue ETL Job Outputs
# -----------------------------------------------------------------------------

output "glue_job" {
  description = "Glue ETL job information"
  value = {
    name              = aws_glue_job.consolidation.name
    arn               = aws_glue_job.consolidation.arn
    script_location   = aws_glue_job.consolidation.command[0].script_location
    worker_type       = aws_glue_job.consolidation.worker_type
    number_of_workers = aws_glue_job.consolidation.number_of_workers
    glue_version      = aws_glue_job.consolidation.glue_version
    timeout_minutes   = aws_glue_job.consolidation.timeout
    max_retries       = aws_glue_job.consolidation.max_retries
  }
}

# -----------------------------------------------------------------------------
# EventBridge Scheduler Outputs
# -----------------------------------------------------------------------------

output "eventbridge_schedulers" {
  description = "EventBridge scheduler information"
  value = var.enable_scheduler ? {
    enabled             = true
    count               = length(aws_scheduler_schedule.glue_consolidation)
    schedule_names      = aws_scheduler_schedule.glue_consolidation[*].name
    schedule_arns       = aws_scheduler_schedule.glue_consolidation[*].arn
    cron_expressions    = local.schedule_cron_expressions
    timezone            = var.scheduler_timezone
    executions_per_day  = var.consolidation_executions_per_day
    execution_times     = [
      for i in range(var.consolidation_executions_per_day) :
      format("%02d:30", i * local.schedule_interval_hours)
    ]
  } : {
    enabled = false
    message = "EventBridge Scheduler is disabled. Set enable_scheduler = true to enable."
  }
}

# -----------------------------------------------------------------------------
# S3 Path Outputs
# -----------------------------------------------------------------------------

output "s3_paths" {
  description = "S3 paths for data and Glue resources"
  value = {
    landing_zone    = local.landing_zone_s3_path
    consolidated    = local.consolidated_s3_path
    glue_scripts    = local.glue_scripts_s3_path
    glue_temp       = local.glue_temp_s3_path
    glue_spark_logs = local.glue_spark_logs_s3_path
  }
}

# -----------------------------------------------------------------------------
# IAM Role Outputs
# -----------------------------------------------------------------------------

output "iam_roles" {
  description = "IAM roles created for Phase 4"
  value = {
    glue_role = {
      name = aws_iam_role.glue.name
      arn  = aws_iam_role.glue.arn
    }
    eventbridge_scheduler_role = {
      name = aws_iam_role.eventbridge_scheduler.name
      arn  = aws_iam_role.eventbridge_scheduler.arn
    }
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Monitoring Outputs
# -----------------------------------------------------------------------------

output "cloudwatch_monitoring" {
  description = "CloudWatch monitoring resources"
  value = {
    dashboard = {
      name = aws_cloudwatch_dashboard.glue_consolidation.dashboard_name
      url  = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.glue_consolidation.dashboard_name}"
    }
    log_groups = {
      crawler = local.glue_crawler_log_group
      job     = local.glue_job_log_group
    }
    alarms_enabled = var.enable_cloudwatch_alarms
    sns_topic_arn  = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? aws_sns_topic.glue_alerts[0].arn : null
  }
}

# -----------------------------------------------------------------------------
# Data Configuration Outputs
# -----------------------------------------------------------------------------

output "data_configuration" {
  description = "Data processing configuration"
  value = {
    consolidation = {
      executions_per_day  = var.consolidation_executions_per_day
      output_files        = var.consolidation_output_files
      compression_codec   = var.parquet_compression_codec
      schedule_interval   = "${local.schedule_interval_hours} hours"
    }
    retention = {
      landing_zone = {
        enabled = var.landing_zone_retention_enabled
        days    = var.landing_zone_retention_days
      }
      consolidated = {
        enabled = var.consolidated_data_retention_enabled
        days    = var.consolidated_data_retention_days
      }
    }
    estimated_volumes = {
      daily_chargebacks     = local.daily_chargebacks
      records_per_execution = local.records_per_execution
      records_per_file      = local.records_per_file
      file_size_mb          = local.file_size_mb
    }
  }
}

# -----------------------------------------------------------------------------
# Operational Commands Outputs
# -----------------------------------------------------------------------------

output "operational_commands" {
  description = "Useful AWS CLI commands for operations"
  value = {
    start_crawler = "aws glue start-crawler --name ${aws_glue_crawler.landing_zone.name} --region ${local.region}"
    
    start_job = "aws glue start-job-run --job-name ${aws_glue_job.consolidation.name} --region ${local.region}"
    
    get_crawler_status = "aws glue get-crawler --name ${aws_glue_crawler.landing_zone.name} --region ${local.region} --query 'Crawler.State'"
    
    get_job_runs = "aws glue get-job-runs --job-name ${aws_glue_job.consolidation.name} --region ${local.region} --max-results 10"
    
    query_consolidated_data = "aws athena start-query-execution --query-string \"SELECT * FROM ${local.glue_database_name}.${local.consolidated_table_name} LIMIT 10\" --result-configuration OutputLocation=s3://${var.parquet_bucket_name}/athena-results/ --region ${local.region}"
    
    view_crawler_logs = "aws logs tail ${local.glue_crawler_log_group} --follow --region ${local.region}"
    
    view_job_logs = "aws logs tail ${local.glue_job_log_group} --follow --region ${local.region}"
  }
}

# -----------------------------------------------------------------------------
# Cost Estimation Outputs
# -----------------------------------------------------------------------------

output "estimated_monthly_costs" {
  description = "Estimated monthly costs for Phase 4 (USD)"
  value = {
    glue_crawler = {
      runs_per_month   = var.consolidation_executions_per_day * 30
      minutes_per_run  = 5
      dpu_hours        = (var.consolidation_executions_per_day * 30 * 5) / 60
      cost_per_dpu     = 0.44
      monthly_cost     = format("$%.2f", ((var.consolidation_executions_per_day * 30 * 5) / 60) * 0.44)
    }
    glue_etl_job = {
      runs_per_month   = var.consolidation_executions_per_day * 30
      minutes_per_run  = 20
      dpus             = var.glue_job_worker_type == "G.1X" ? var.glue_job_number_of_workers : var.glue_job_number_of_workers * 2
      dpu_hours        = ((var.consolidation_executions_per_day * 30 * 20) / 60) * (var.glue_job_worker_type == "G.1X" ? var.glue_job_number_of_workers : var.glue_job_number_of_workers * 2)
      cost_per_dpu     = 0.44
      monthly_cost     = format("$%.2f", (((var.consolidation_executions_per_day * 30 * 20) / 60) * (var.glue_job_worker_type == "G.1X" ? var.glue_job_number_of_workers : var.glue_job_number_of_workers * 2)) * 0.44)
    }
    data_catalog = {
      message      = "First 1M objects free"
      monthly_cost = "$0.00"
    }
    s3_storage = {
      landing_size_gb = format("%.2f", (local.daily_chargebacks * 100 * (var.landing_zone_retention_enabled ? var.landing_zone_retention_days : 30)) / 1024 / 1024 / 1024)
      consolidated_size_gb = format("%.2f", (local.daily_chargebacks * 100 * 30) / 1024 / 1024 / 1024)
      cost_per_gb = 0.023
      estimated_monthly_cost = format("$%.2f", (((local.daily_chargebacks * 100 * 30) / 1024 / 1024 / 1024) * 2) * 0.023)
    }
    total_estimated = "See individual components above - typically $30-50/month"
  }
}

# -----------------------------------------------------------------------------
# Summary Output (Quick Reference)
# -----------------------------------------------------------------------------

output "phase4_summary" {
  description = "Phase 4 deployment summary"
  value = <<-EOT
    
    ═══════════════════════════════════════════════════════════════════
    Phase 4: Data Consolidation & Analytics - Deployment Summary
    ═══════════════════════════════════════════════════════════════════
    
    📊 Glue Database: ${aws_glue_catalog_database.chargeback_data.name}
    🔍 Crawler: ${aws_glue_crawler.landing_zone.name}
    ⚙️  ETL Job: ${aws_glue_job.consolidation.name}
    📅 Schedulers: ${var.enable_scheduler ? length(aws_scheduler_schedule.glue_consolidation) : 0} schedules
    
    ⏰ Execution Schedule:
    ${var.enable_scheduler ? join("\n    ", [for i in range(var.consolidation_executions_per_day) : format("- %02d:30 %s", i * local.schedule_interval_hours, var.scheduler_timezone)]) : "   - Scheduler disabled"}
    
    📦 Output Configuration:
    - ${var.consolidation_output_files} consolidated files per execution
    - ${local.records_per_file} records per file
    - ~${local.file_size_mb} MB per file
    
    💰 Estimated Cost: $30-50/month
    
    📈 Dashboard: 
    ${aws_cloudwatch_dashboard.glue_consolidation.dashboard_name}
    
    🚀 Next Steps:
    1. Run crawler: aws glue start-crawler --name ${aws_glue_crawler.landing_zone.name}
    2. Verify tables in Glue Data Catalog
    3. Wait for scheduled ETL jobs or trigger manually
    4. Monitor in CloudWatch dashboard
    
    ═══════════════════════════════════════════════════════════════════
  EOT
}
