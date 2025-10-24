# =============================================================================
# Phase 3 - Outputs
# =============================================================================
# This file exports important values from Phase 3 for use by other modules
# or for reference by operators.
# =============================================================================

# -----------------------------------------------------------------------------
# MSK Cluster Outputs
# -----------------------------------------------------------------------------

output "msk_cluster_arn" {
  description = "ARN of the MSK Serverless cluster"
  value       = aws_msk_serverless_cluster.main.arn
}

output "msk_cluster_name" {
  description = "Name of the MSK Serverless cluster"
  value       = aws_msk_serverless_cluster.main.cluster_name
}

output "msk_bootstrap_brokers" {
  description = "MSK bootstrap brokers connection string (IAM authentication)"
  value       = aws_msk_serverless_cluster.main.bootstrap_brokers_sasl_iam
  sensitive   = false
}

output "msk_security_group_id" {
  description = "Security group ID for MSK cluster"
  value       = aws_security_group.msk.id
}

output "kafka_topic_name" {
  description = "Name of the Kafka topic for chargebacks"
  value       = var.kafka_topic_name
}

# -----------------------------------------------------------------------------
# Lambda Outputs
# -----------------------------------------------------------------------------

output "lambda_function_arn" {
  description = "ARN of the Lambda stream processor function"
  value       = aws_lambda_function.stream_processor.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda stream processor function"
  value       = aws_lambda_function.stream_processor.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_stream_processor.arn
}

output "lambda_security_group_id" {
  description = "Security group ID of the Lambda function"
  value       = aws_security_group.lambda_stream_processor.id
}

output "lambda_log_group_name" {
  description = "CloudWatch Log Group name for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "lambda_dlq_url" {
  description = "URL of the Lambda Dead Letter Queue (if enabled)"
  value       = var.enable_dlq ? aws_sqs_queue.lambda_dlq[0].url : ""
}

# -----------------------------------------------------------------------------
# Kinesis Data Analytics (Flink) Outputs
# -----------------------------------------------------------------------------

output "flink_application_arn" {
  description = "ARN of the Kinesis Data Analytics Flink application"
  value       = aws_kinesisanalyticsv2_application.flink_parquet_writer.arn
}

output "flink_application_name" {
  description = "Name of the Kinesis Data Analytics Flink application"
  value       = aws_kinesisanalyticsv2_application.flink_parquet_writer.name
}

output "flink_application_id" {
  description = "ID of the Kinesis Data Analytics Flink application"
  value       = aws_kinesisanalyticsv2_application.flink_parquet_writer.id
}

output "flink_application_version" {
  description = "Version of the Kinesis Data Analytics Flink application"
  value       = aws_kinesisanalyticsv2_application.flink_parquet_writer.version_id
}

output "flink_role_arn" {
  description = "ARN of the Flink application execution role"
  value       = aws_iam_role.flink_application.arn
}

output "flink_log_group_name" {
  description = "CloudWatch Log Group name for Flink application"
  value       = aws_cloudwatch_log_group.flink.name
}

# -----------------------------------------------------------------------------
# S3 Outputs
# -----------------------------------------------------------------------------

output "parquet_output_path" {
  description = "S3 path where Flink writes Parquet files"
  value       = "s3://${var.parquet_bucket_name}/${local.parquet_output_prefix}/"
}

output "flink_checkpoint_path" {
  description = "S3 path for Flink checkpoints"
  value       = "s3://${var.parquet_bucket_name}/${local.flink_checkpoint_prefix}/"
}

output "flink_jar_path" {
  description = "Expected S3 path for Flink application JAR"
  value       = "s3://${var.parquet_bucket_name}/${local.flink_application_jar_key}"
}

# -----------------------------------------------------------------------------
# CloudWatch Outputs
# -----------------------------------------------------------------------------

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch Dashboard for Phase 3 monitoring"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.phase3.dashboard_name}"
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.phase3.dashboard_name
}

output "sns_topic_arn" {
  description = "SNS Topic ARN for CloudWatch alarms (if email configured)"
  value       = var.alarm_email_endpoint != "" ? aws_sns_topic.alarms[0].arn : ""
}

# -----------------------------------------------------------------------------
# Deployment Summary
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of Phase 3 deployment with useful commands and URLs"
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════════════════╗
    ║                    PHASE 3 - DEPLOYMENT SUMMARY                            ║
    ╚════════════════════════════════════════════════════════════════════════════╝
    
    📊 INFRASTRUCTURE DEPLOYED:
    ────────────────────────────────────────────────────────────────────────────
    ✓ MSK Serverless Cluster:     ${aws_msk_serverless_cluster.main.cluster_name}
    ✓ Lambda Stream Processor:     ${aws_lambda_function.stream_processor.function_name}
    ✓ Flink Application:           ${aws_kinesisanalyticsv2_application.flink_parquet_writer.name}
    ✓ Kafka Topic:                 ${var.kafka_topic_name}
    
    🔗 MSK CONNECTION:
    ────────────────────────────────────────────────────────────────────────────
    Bootstrap Servers (IAM):
      ${aws_msk_serverless_cluster.main.bootstrap_brokers_sasl_iam}
    
    📝 CLOUDWATCH LOGS:
    ────────────────────────────────────────────────────────────────────────────
    Lambda Logs:
      aws logs tail ${aws_cloudwatch_log_group.lambda.name} --follow
    
    Flink Logs:
      aws logs tail ${aws_cloudwatch_log_group.flink.name} --follow
    
    📊 MONITORING:
    ────────────────────────────────────────────────────────────────────────────
    Dashboard: ${aws_cloudwatch_dashboard.phase3.dashboard_name}
    URL: https://console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.phase3.dashboard_name}
    
    📦 NEXT STEPS:
    ────────────────────────────────────────────────────────────────────────────
    
    1️⃣  CREATE KAFKA TOPIC:
        See msk.tf comments for topic creation commands
    
    2️⃣  DEPLOY LAMBDA CODE:
        cd deployments/lambda/stream-processor
        pip install -r requirements.txt -t .
        zip -r ../stream-processor.zip .
        
    3️⃣  BUILD FLINK JAR:
        See PHASE3_README.md for complete Flink application code
        
    4️⃣  UPLOAD FLINK JAR:
        aws s3 cp target/application.jar \
          s3://${var.parquet_bucket_name}/${local.flink_application_jar_key}
    
    5️⃣  START FLINK APPLICATION:
        aws kinesisanalyticsv2 start-application \
          --application-name ${aws_kinesisanalyticsv2_application.flink_parquet_writer.name} \
          --region ${local.region}
    
    6️⃣  TEST THE PIPELINE:
        Create a chargeback via Phase 2 API and watch it flow through!
    
    💰 ESTIMATED MONTHLY COST:
    ────────────────────────────────────────────────────────────────────────────
    • MSK Serverless:          ~$60/month  (depends on throughput)
    • Lambda:                  ~$5/month   (depends on invocations)
    • Flink (1 KPU):          ~$80/month  (24/7 runtime)
    • CloudWatch Logs (1 day): ~$1/month
    ────────────────────────────────────────────────────────────────────────────
    TOTAL PHASE 3:             ~$146/month
    
    📚 DOCUMENTATION:
    ────────────────────────────────────────────────────────────────────────────
    Complete guide: PHASE3_README.md
    
    ╚════════════════════════════════════════════════════════════════════════════╝
  EOT
}

# -----------------------------------------------------------------------------
# Configuration Summary (for debugging)
# -----------------------------------------------------------------------------

output "configuration" {
  description = "Phase 3 configuration summary"
  value = {
    project_name         = var.project_name
    environment          = var.environment
    region               = local.region
    lambda_runtime       = var.lambda_runtime
    lambda_memory        = var.lambda_memory_size
    flink_runtime        = var.flink_runtime_environment
    flink_parallelism    = var.flink_parallelism
    kafka_partitions     = var.kafka_topic_partitions
    checkpointing_enabled = var.flink_checkpointing_enabled
    checkpoint_interval  = var.flink_checkpoint_interval
  }
}
