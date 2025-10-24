# =============================================================================
# Phase 3 Data Sources - Import resources from Phase 1
# =============================================================================
# This file imports outputs from Phase 1 to enable Phase 3 integration.
# Phase 3 needs: VPC, Subnets, DynamoDB Stream ARN, S3 Parquet Bucket
# 
# Note: All required variables from Phase 1 are declared in variables.tf
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
  
  # Common tags for all Phase 3 resources
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      Phase       = "3"
      ManagedBy   = "Terraform"
      Purpose     = "Streaming-Pipeline"
      Component   = "MSK-Flink"
    },
    var.tags
  )
  
  # Resource-specific naming
  msk_cluster_name          = "${local.name_prefix}-${var.msk_cluster_name}"
  lambda_function_name      = "${local.name_prefix}-${var.lambda_stream_processor_name}"
  flink_application_name    = "${local.name_prefix}-${var.flink_application_name}"
  
  # Security group names
  msk_security_group_name    = "${local.name_prefix}-msk-sg"
  lambda_security_group_name = "${local.name_prefix}-lambda-stream-processor-sg"
  
  # CloudWatch Log Groups
  lambda_log_group_name = "/aws/lambda/${local.lambda_function_name}"
  flink_log_group_name  = "/aws/kinesisanalytics/${local.flink_application_name}"
  
  # S3 paths
  flink_application_jar_key = "flink/applications/${var.flink_application_name}/application.jar"
  flink_checkpoint_prefix   = "flink/checkpoints/${var.flink_application_name}"
  parquet_output_prefix     = var.s3_landing_prefix
  
  # Lambda deployment package path (path.root points to where terraform is executed)
  lambda_zip_path = "${path.module}/../../../../deployments/lambda/stream-processor.zip"
  
  # MSK configuration
  kafka_version = "2.8.1" # Compatible with MSK Serverless
  
  # Flink application configuration
  flink_application_properties = {
    # Kafka source configuration
    "kafka.bootstrap.servers" = "" # Will be populated after MSK creation
    "kafka.topic"             = var.kafka_topic_name
    "kafka.group.id"          = "${var.flink_application_name}-consumer-group"
    
    # S3 sink configuration
    "s3.bucket"       = var.parquet_bucket_name
    "s3.prefix"       = local.parquet_output_prefix
    "s3.region"       = local.region
    
    # Parquet configuration
    "parquet.compression" = var.parquet_compression_codec
    "parquet.block.size"  = "134217728" # 128MB
    "parquet.page.size"   = "1048576"   # 1MB
    
    # Checkpointing configuration
    "checkpoint.enabled"  = tostring(var.flink_checkpointing_enabled)
    "checkpoint.interval" = tostring(var.flink_checkpoint_interval)
    
    # Logging
    "log.level" = var.flink_log_level
  }
}

# -----------------------------------------------------------------------------
# Data Source: Availability Zones
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
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
