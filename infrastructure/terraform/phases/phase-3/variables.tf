# =============================================================================
# Phase 3 Variables - MSK Streaming & Flink Processing
# =============================================================================
# This file defines all configurable parameters for Phase 3 infrastructure.
# Phase 3 implements real-time streaming pipeline:
# DynamoDB Streams → Lambda (Python) → MSK Serverless → Flink → S3 Parquet
# =============================================================================

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "poc-chargeback"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Phase 1 Imported Resources
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID from Phase 1 (for MSK and Lambda networking)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from Phase 1 (for Lambda and MSK)"
  type        = list(string)
}

variable "security_group_dynamodb_id" {
  description = "Security group ID for DynamoDB access from Phase 1"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name from Phase 1"
  type        = string
}

variable "dynamodb_stream_arn" {
  description = "DynamoDB Stream ARN from Phase 1 (Lambda event source)"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB table ARN from Phase 1 (for IAM policies)"
  type        = string
}

variable "parquet_bucket_name" {
  description = "Parquet bucket name from Phase 1 (Flink output destination)"
  type        = string
}

variable "parquet_bucket_arn" {
  description = "Parquet bucket ARN from Phase 1 (for IAM policies)"
  type        = string
}

variable "csv_bucket_name" {
  description = "CSV bucket name from Phase 1"
  type        = string
}

variable "csv_bucket_arn" {
  description = "CSV bucket ARN from Phase 1"
  type        = string
}

variable "s3_vpc_endpoint_id" {
  description = "S3 VPC Endpoint ID from Phase 1 (for Lambda S3 access)"
  type        = string
}

variable "dynamodb_vpc_endpoint_id" {
  description = "DynamoDB VPC Endpoint ID from Phase 1"
  type        = string
}

# -----------------------------------------------------------------------------
# Amazon MSK Serverless Configuration
# -----------------------------------------------------------------------------

variable "msk_cluster_name" {
  description = "Name of the MSK Serverless cluster"
  type        = string
  default     = "chargebacks-cluster"
}

variable "kafka_topic_name" {
  description = "Kafka topic name for chargeback events"
  type        = string
  default     = "chargebacks"
}

variable "kafka_topic_partitions" {
  description = "Number of partitions for the Kafka topic"
  type        = number
  default     = 3

  validation {
    condition     = var.kafka_topic_partitions >= 1 && var.kafka_topic_partitions <= 100
    error_message = "Topic partitions must be between 1 and 100."
  }
}

variable "kafka_topic_replication_factor" {
  description = "Replication factor for the Kafka topic (MSK Serverless requires 3)"
  type        = number
  default     = 3

  validation {
    condition     = var.kafka_topic_replication_factor == 3
    error_message = "MSK Serverless requires replication factor of 3."
  }
}

# -----------------------------------------------------------------------------
# Lambda Stream Processor Configuration (Python 3)
# -----------------------------------------------------------------------------

variable "lambda_stream_processor_name" {
  description = "Name of the Lambda function that processes DynamoDB Streams"
  type        = string
  default     = "stream-processor"
}

variable "lambda_runtime" {
  description = "Python runtime version for Lambda"
  type        = string
  default     = "python3.11"

  validation {
    condition     = can(regex("^python3\\.(9|10|11|12)$", var.lambda_runtime))
    error_message = "Runtime must be python3.9, python3.10, python3.11, or python3.12."
  }
}

variable "lambda_memory_size" {
  description = "Memory allocation for Lambda function (MB)"
  type        = number
  default     = 512

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Memory must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function (seconds)"
  type        = number
  default     = 60

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_batch_size" {
  description = "Number of DynamoDB Stream records to process per Lambda invocation"
  type        = number
  default     = 100

  validation {
    condition     = var.lambda_batch_size >= 1 && var.lambda_batch_size <= 10000
    error_message = "Batch size must be between 1 and 10000."
  }
}

variable "lambda_parallelization_factor" {
  description = "Number of concurrent batches per shard (1-10)"
  type        = number
  default     = 1

  validation {
    condition     = var.lambda_parallelization_factor >= 1 && var.lambda_parallelization_factor <= 10
    error_message = "Parallelization factor must be between 1 and 10."
  }
}

variable "lambda_retry_attempts" {
  description = "Maximum retry attempts for failed records"
  type        = number
  default     = 3

  validation {
    condition     = var.lambda_retry_attempts >= 0 && var.lambda_retry_attempts <= 10
    error_message = "Retry attempts must be between 0 and 10."
  }
}

variable "lambda_maximum_record_age" {
  description = "Maximum age of a record that Lambda processes (seconds, -1 to disable)"
  type        = number
  default     = 3600 # 1 hour

  validation {
    condition     = var.lambda_maximum_record_age == -1 || (var.lambda_maximum_record_age >= 60 && var.lambda_maximum_record_age <= 604800)
    error_message = "Maximum record age must be -1 (disabled) or between 60 and 604800 seconds."
  }
}

# -----------------------------------------------------------------------------
# Kinesis Data Analytics (Flink) Configuration
# -----------------------------------------------------------------------------

variable "flink_application_name" {
  description = "Name of the Kinesis Data Analytics Flink application"
  type        = string
  default     = "chargeback-parquet-writer"
}

variable "flink_runtime_environment" {
  description = "Flink runtime environment version"
  type        = string
  default     = "FLINK-1_15"

  validation {
    condition     = contains(["FLINK-1_13", "FLINK-1_15", "FLINK-1_18"], var.flink_runtime_environment)
    error_message = "Runtime must be FLINK-1_13, FLINK-1_15, or FLINK-1_18."
  }
}

variable "flink_parallelism" {
  description = "Parallelism count (KPU) for Flink application (1 KPU = 1 vCPU, 4GB RAM)"
  type        = number
  default     = 1

  validation {
    condition     = var.flink_parallelism >= 1 && var.flink_parallelism <= 32
    error_message = "Parallelism must be between 1 and 32 KPUs."
  }
}

variable "flink_parallelism_per_kpu" {
  description = "Parallelism per KPU (tasks running per KPU)"
  type        = number
  default     = 1

  validation {
    condition     = var.flink_parallelism_per_kpu >= 1 && var.flink_parallelism_per_kpu <= 8
    error_message = "Parallelism per KPU must be between 1 and 8."
  }
}

variable "flink_checkpointing_enabled" {
  description = "Enable Flink checkpointing for fault tolerance"
  type        = bool
  default     = true
}

variable "flink_checkpoint_interval" {
  description = "Checkpoint interval in milliseconds"
  type        = number
  default     = 60000 # 60 seconds

  validation {
    condition     = var.flink_checkpoint_interval >= 1000 && var.flink_checkpoint_interval <= 3600000
    error_message = "Checkpoint interval must be between 1 second and 1 hour."
  }
}

variable "flink_log_level" {
  description = "Log level for Flink application"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["ERROR", "WARN", "INFO", "DEBUG"], var.flink_log_level)
    error_message = "Log level must be ERROR, WARN, INFO, or DEBUG."
  }
}

# -----------------------------------------------------------------------------
# S3 Landing Zone Configuration
# -----------------------------------------------------------------------------

variable "s3_landing_prefix" {
  description = "S3 prefix for landing zone parquet files"
  type        = string
  default     = "landing/chargebacks"
}

variable "parquet_compression_codec" {
  description = "Compression codec for Parquet files (SNAPPY, GZIP, LZO, UNCOMPRESSED)"
  type        = string
  default     = "SNAPPY"

  validation {
    condition     = contains(["SNAPPY", "GZIP", "LZO", "UNCOMPRESSED"], var.parquet_compression_codec)
    error_message = "Compression must be SNAPPY, GZIP, LZO, or UNCOMPRESSED."
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Configuration
# -----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 1 # 1 day for POC

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Invalid retention period."
  }
}

variable "enable_msk_monitoring" {
  description = "Enable enhanced monitoring for MSK cluster"
  type        = bool
  default     = true
}

variable "enable_lambda_insights" {
  description = "Enable Lambda Insights for enhanced monitoring"
  type        = bool
  default     = false # Disabled for POC to reduce costs
}

variable "enable_flink_metrics" {
  description = "Enable detailed CloudWatch metrics for Flink"
  type        = bool
  default     = true
}

variable "alarm_email_endpoint" {
  description = "Email address for CloudWatch alarm notifications (optional)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "create_vpc_endpoints" {
  description = "Create VPC endpoints for MSK (not needed for Serverless, but available)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Resource Tagging
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all Phase 3 resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing for Lambda"
  type        = bool
  default     = false # Disabled for POC to reduce costs
}

variable "enable_dlq" {
  description = "Enable Dead Letter Queue for failed Lambda invocations"
  type        = bool
  default     = true
}

variable "create_kafka_topic_terraform" {
  description = "Create Kafka topic via Terraform (requires kafka provider)"
  type        = bool
  default     = false # Manual creation recommended for MSK Serverless
}

# -----------------------------------------------------------------------------
# Cost Optimization
# -----------------------------------------------------------------------------

variable "auto_scaling_enabled" {
  description = "Enable auto-scaling for Flink application (requires monitoring)"
  type        = bool
  default     = false # Disabled for POC
}

variable "snapshot_enabled" {
  description = "Enable snapshots for Flink application state"
  type        = bool
  default     = true
}
