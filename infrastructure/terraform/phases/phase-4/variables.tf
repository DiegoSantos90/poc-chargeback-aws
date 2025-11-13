# =============================================================================
# Phase 4 - AWS Glue Data Consolidation Variables
# =============================================================================
# This file defines all configurable variables for Phase 4 infrastructure.
# Phase 4 consolidates thousands of small Parquet files from Phase 3 into
# optimized, partitioned datasets for efficient querying and analytics.
# =============================================================================

# -----------------------------------------------------------------------------
# Project Configuration (from Phase 1)
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "poc-chargeback"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "sa-east-1"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Phase 1 Imports (S3 Buckets)
# -----------------------------------------------------------------------------

variable "parquet_bucket_name" {
  description = "Name of the S3 bucket containing landing zone Parquet files (from Phase 1)"
  type        = string
}

variable "parquet_bucket_arn" {
  description = "ARN of the Parquet S3 bucket (from Phase 1)"
  type        = string
}

# -----------------------------------------------------------------------------
# AWS Glue Database Configuration
# -----------------------------------------------------------------------------

variable "glue_database_name" {
  description = "Name of the Glue database for chargeback data catalog"
  type        = string
  default     = "chargeback_data"
}

variable "glue_database_description" {
  description = "Description of the Glue database"
  type        = string
  default     = "Chargeback data catalog with landing and consolidated tables"
}

# -----------------------------------------------------------------------------
# AWS Glue Crawler Configuration
# -----------------------------------------------------------------------------

variable "glue_crawler_name" {
  description = "Name of the Glue crawler for landing zone discovery"
  type        = string
  default     = "chargebacks-landing-crawler"
}

variable "glue_crawler_schedule" {
  description = "Cron expression for Glue crawler schedule (runs before ETL jobs)"
  type        = string
  default     = "cron(0 0,6,12,18 * * ? *)" # Every 6 hours at 00:00, 06:00, 12:00, 18:00 UTC
  # Runs 30 minutes before ETL to ensure catalog is updated
}

variable "glue_crawler_table_prefix" {
  description = "Prefix for tables created by the crawler"
  type        = string
  default     = "landing_"
}

# -----------------------------------------------------------------------------
# AWS Glue ETL Job Configuration
# -----------------------------------------------------------------------------

variable "glue_job_name" {
  description = "Name of the Glue ETL job for data consolidation"
  type        = string
  default     = "chargebacks-consolidation"
}

variable "glue_job_worker_type" {
  description = "Worker type for Glue job (G.1X, G.2X, G.4X, G.8X)"
  type        = string
  default     = "G.1X" # 1 DPU (4 vCPU, 16 GB memory) - sufficient for 5M records/day
  # Scale up to G.2X or more workers if processing >10M records
}

variable "glue_job_number_of_workers" {
  description = "Number of workers for Glue job (scales for 5M chargebacks/day)"
  type        = number
  default     = 2 # 2 workers × 1 DPU = 2 DPUs total
  # For 5M records: ~10 workers can process in 15-20 minutes
  # Increase to 20-30 for near-real-time processing
}

variable "glue_job_timeout" {
  description = "Timeout for Glue job in minutes"
  type        = number
  default     = 60 # 1 hour max (should complete in 15-20 min for 5M records)
}

variable "glue_job_max_retries" {
  description = "Maximum number of retries for failed Glue jobs"
  type        = number
  default     = 1
}

variable "glue_job_max_concurrent_runs" {
  description = "Maximum number of concurrent runs for the Glue job"
  type        = number
  default     = 1 # Prevent overlapping executions
}

# -----------------------------------------------------------------------------
# Data Consolidation Configuration
# -----------------------------------------------------------------------------

variable "consolidation_output_files" {
  description = "Number of consolidated Parquet files to generate per execution (repartition count)"
  type        = number
  default     = 1
  # For 5M records/day ÷ 4 executions = 1.25M records/execution
  # For 1 execution: 5M records/execution
  # Adjust based on file size preference: fewer files = larger files
}

variable "consolidation_executions_per_day" {
  description = "Number of times per day to run consolidation (used for EventBridge schedule)"
  type        = number
  default     = 4
  # 4 times/day = every 6 hours
  # Can be changed to 2 (every 12h), 8 (every 3h), 24 (hourly), etc.
}

variable "output_format" {
  description = "Output file format for consolidated data"
  type        = string
  default     = "csv"
  # Options: csv, parquet, json
  # csv = human-readable, widely compatible
  # parquet = columnar, optimized for analytics (original default)
  
  validation {
    condition     = contains(["csv", "parquet", "json"], var.output_format)
    error_message = "Output format must be csv, parquet, or json"
  }
}

variable "csv_delimiter" {
  description = "Delimiter for CSV output files"
  type        = string
  default     = ","
  # Common options: comma (,), pipe (|), tab (\t), semicolon (;)
}

variable "csv_header" {
  description = "Include header row in CSV output"
  type        = bool
  default     = true
}

variable "csv_quote_char" {
  description = "Quote character for CSV fields"
  type        = string
  default     = "\""
}

variable "parquet_compression_codec" {
  description = "Compression codec for Parquet files (only used if output_format = parquet)"
  type        = string
  default     = "snappy"
  # Options: snappy (fast), gzip (smaller), lzo, brotli, zstd
  # snappy = best balance of speed and compression for analytics
}

# -----------------------------------------------------------------------------
# S3 Path Configuration
# -----------------------------------------------------------------------------

variable "s3_landing_prefix" {
  description = "S3 prefix for landing zone Parquet files (from Phase 3 Flink output)"
  type        = string
  default     = "landing/chargebacks"
  # Phase 3 Flink writes to: s3://bucket/landing/chargebacks/YYYY/MM/DD/file.parquet
}

variable "s3_consolidated_prefix" {
  description = "S3 prefix for consolidated Parquet files (Phase 4 output)"
  type        = string
  default     = "consolidated/chargebacks"
  # Phase 4 writes to: s3://bucket/consolidated/chargebacks/year=YYYY/month=MM/day=DD/part-*.parquet
}

variable "s3_glue_scripts_prefix" {
  description = "S3 prefix for Glue job scripts"
  type        = string
  default     = "glue-scripts"
}

variable "s3_glue_temp_prefix" {
  description = "S3 prefix for Glue temporary files"
  type        = string
  default     = "glue-temp"
}

variable "s3_glue_spark_logs_prefix" {
  description = "S3 prefix for Glue Spark logs"
  type        = string
  default     = "glue-logs/spark"
}

# -----------------------------------------------------------------------------
# Data Retention Configuration
# -----------------------------------------------------------------------------

variable "landing_zone_retention_enabled" {
  description = "Enable lifecycle policy to delete landing zone files after consolidation"
  type        = bool
  default     = false # For POC: keep all data
  # Set to true in production to save costs
}

variable "landing_zone_retention_days" {
  description = "Number of days to retain landing zone files before deletion (if retention enabled)"
  type        = number
  default     = 7
  # Recommended: 7 days (allows reprocessing if consolidation fails)
  # Production: 1-3 days to minimize costs
}

variable "consolidated_data_retention_enabled" {
  description = "Enable lifecycle policy for consolidated data"
  type        = bool
  default     = false # For POC: keep all data
}

variable "consolidated_data_retention_days" {
  description = "Number of days to retain consolidated data before transitioning to cheaper storage"
  type        = number
  default     = 90
  # After 90 days, transition to S3 Glacier for long-term archival
}

# -----------------------------------------------------------------------------
# EventBridge Scheduler Configuration
# -----------------------------------------------------------------------------

variable "enable_scheduler" {
  description = "Enable EventBridge Scheduler to trigger Glue ETL jobs automatically"
  type        = bool
  default     = true
}

variable "scheduler_timezone" {
  description = "Timezone for EventBridge Scheduler (e.g., America/Sao_Paulo, UTC)"
  type        = string
  default     = "America/Sao_Paulo" # Brazil timezone (UTC-3)
}

# Computed schedule expression based on executions_per_day
# 4 executions = every 6 hours: 00:30, 06:30, 12:30, 18:30 (30 min after crawler)
# 2 executions = every 12 hours: 00:30, 12:30
# 24 executions = every hour: XX:30

# -----------------------------------------------------------------------------
# Kafka/MSK Integration Configuration
# -----------------------------------------------------------------------------

variable "enable_kafka_notifications" {
  description = "Enable Kafka notifications for consolidation events"
  type        = bool
  default     = true
}

variable "msk_bootstrap_brokers" {
  description = "MSK bootstrap brokers from Phase 3 (IAM authentication)"
  type        = string
  default     = ""
  # Example: "b-1.msk-cluster.xyz.kafka.us-east-1.amazonaws.com:9098,b-2..."
}

variable "msk_cluster_arn" {
  description = "ARN of the MSK cluster from Phase 3"
  type        = string
  default     = ""
  # Example: "arn:aws:kafka:sa-east-1:123456789012:cluster/msk-cluster/uuid"
}

variable "kafka_consolidation_topic" {
  description = "Kafka topic name for consolidation completion events"
  type        = string
  default     = "chargeback-consolidation-events"
}

variable "kafka_consolidation_topic_partitions" {
  description = "Number of partitions for consolidation events topic"
  type        = number
  default     = 3
}

variable "kafka_consolidation_topic_replication" {
  description = "Replication factor for consolidation events topic (MSK Serverless requires 3)"
  type        = number
  default     = 3
}

variable "msk_security_group_id" {
  description = "Security group ID of the MSK cluster (from Phase 3)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID where MSK is deployed (from Phase 1)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Glue connection to MSK"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# CloudWatch Monitoring Configuration
# -----------------------------------------------------------------------------

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for Glue job failures"
  type        = bool
  default     = true
}

variable "alarm_email_endpoints" {
  description = "Email addresses to notify on Glue job failures (SNS topic)"
  type        = list(string)
  default     = []
  # Example: ["data-team@company.com", "ops@company.com"]
}

# -----------------------------------------------------------------------------
# Glue Job Arguments (passed to PySpark script)
# -----------------------------------------------------------------------------

variable "glue_job_arguments" {
  description = "Additional arguments to pass to the Glue job script"
  type        = map(string)
  default     = {}
  # Example:
  # {
  #   "--enable-metrics"           = "true"
  #   "--enable-continuous-logging" = "true"
  # }
}

# =============================================================================
# VARIABLE VALIDATION RULES
# =============================================================================

# Ensure valid worker types
variable "valid_worker_types" {
  description = "List of valid Glue worker types (for validation)"
  type        = list(string)
  default     = ["G.1X", "G.2X", "G.4X", "G.8X", "Standard", "G.025X"]
}

# Validate worker type
locals {
  is_valid_worker_type = contains(var.valid_worker_types, var.glue_job_worker_type)
}

# Validate executions per day
locals {
  valid_executions_per_day = [1, 2, 3, 4, 6, 8, 12, 24]
  is_valid_executions      = contains(local.valid_executions_per_day, var.consolidation_executions_per_day)
}

# Validate output files
locals {
  is_valid_output_files = var.consolidation_output_files >= 1 && var.consolidation_output_files <= 1000
}
