# =============================================================================
# Phase 3 - Kinesis Data Analytics (Flink) Application
# =============================================================================
# This file creates a Flink application that:
# 1. Consumes messages from MSK Kafka topic
# 2. Processes each record (1:1 mapping)
# 3. Writes Parquet files to S3
# 
# NOTE: This requires a custom Flink JAR application uploaded to S3
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Object for Flink Application JAR (Placeholder)
# -----------------------------------------------------------------------------
# 
# IMPORTANT: You need to upload your Flink application JAR to S3 first!
# 
# Steps to create and upload the JAR:
# 1. Build your Flink application (see PHASE3_README.md for code example)
# 2. Upload to S3:
#    aws s3 cp target/chargeback-parquet-writer-1.0.jar \
#      s3://{bucket-name}/flink/applications/chargeback-parquet-writer/application.jar
# 
# For now, we'll create a placeholder reference

# Uncomment this data source once you've uploaded the JAR
# data "aws_s3_object" "flink_application_jar" {
#   bucket = var.parquet_bucket_name
#   key    = local.flink_application_jar_key
# }

# -----------------------------------------------------------------------------
# Kinesis Data Analytics Application
# -----------------------------------------------------------------------------

resource "aws_kinesisanalyticsv2_application" "flink_parquet_writer" {
  name                   = local.flink_application_name
  runtime_environment    = var.flink_runtime_environment
  service_execution_role = aws_iam_role.flink_application.arn
  description            = "Flink application that consumes from MSK and writes Parquet to S3"

  # Application Configuration
  application_configuration {
    
    # Flink Application Code (JAR from S3)
    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = var.parquet_bucket_arn
          file_key   = local.flink_application_jar_key
        }
      }
      code_content_type = "ZIPFILE" # JAR file
    }

    # VPC Configuration (required to access MSK)
    vpc_configuration {
      security_group_ids = [aws_security_group.msk.id]
      subnet_ids         = var.private_subnet_ids
    }

    # Flink Application Configuration
    flink_application_configuration {
      
      # Checkpointing Configuration
      checkpoint_configuration {
        configuration_type = "CUSTOM"
        checkpointing_enabled = var.flink_checkpointing_enabled
        checkpoint_interval    = var.flink_checkpoint_interval
        min_pause_between_checkpoints = var.flink_checkpoint_interval / 2
      }

      # Monitoring Configuration
      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level         = var.flink_log_level
        metrics_level     = var.enable_flink_metrics ? "APPLICATION" : "TASK"
      }

      # Parallelism Configuration
      parallelism_configuration {
        configuration_type   = "CUSTOM"
        parallelism          = var.flink_parallelism
        parallelism_per_kpu  = var.flink_parallelism_per_kpu
        auto_scaling_enabled = var.auto_scaling_enabled
      }
    }

    # Environment Properties (passed to Flink application)
    environment_properties {
      property_group {
        property_group_id = "KafkaSource"
        
        property_map = {
          "bootstrap.servers"     = aws_msk_serverless_cluster.main.bootstrap_brokers_sasl_iam
          "topic"                 = var.kafka_topic_name
          "group.id"              = "${local.flink_application_name}-consumer-group"
          "security.protocol"     = "SASL_SSL"
          "sasl.mechanism"        = "AWS_MSK_IAM"
          "sasl.jaas.config"      = "software.amazon.msk.auth.iam.IAMLoginModule required;"
          "sasl.client.callback.handler.class" = "software.amazon.msk.auth.iam.IAMClientCallbackHandler"
        }
      }

      property_group {
        property_group_id = "S3Sink"
        
        property_map = {
          "bucket"            = var.parquet_bucket_name
          "prefix"            = local.parquet_output_prefix
          "region"            = local.region
          "checkpoint.prefix" = local.flink_checkpoint_prefix
        }
      }

      property_group {
        property_group_id = "ParquetConfig"
        
        property_map = {
          "compression.codec" = var.parquet_compression_codec
          "block.size"        = "134217728" # 128MB
          "page.size"         = "1048576"   # 1MB
          "enable.dictionary" = "true"
        }
      }

      property_group {
        property_group_id = "ApplicationConfig"
        
        property_map = {
          "environment"           = var.environment
          "checkpoint.enabled"    = tostring(var.flink_checkpointing_enabled)
          "checkpoint.interval.ms" = tostring(var.flink_checkpoint_interval)
        }
      }
    }
  }

  # CloudWatch Logging
  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.flink.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.flink_application_name
    }
  )

  # Lifecycle: Ignore changes to application configuration during updates
  # This allows for in-place updates without destroying the application
  lifecycle {
    ignore_changes = [
      application_configuration[0].application_code_configuration[0].code_content[0].s3_content_location[0].object_version
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.flink,
    aws_cloudwatch_log_stream.flink,
    aws_iam_role.flink_application
  ]
}

# -----------------------------------------------------------------------------
# Application Snapshot Configuration (Optional)
# -----------------------------------------------------------------------------
# 
# Snapshots allow you to save the state of your Flink application
# Useful for version upgrades or disaster recovery

resource "aws_kinesisanalyticsv2_application_snapshot" "flink_snapshot" {
  count = var.snapshot_enabled ? 1 : 0

  application_name = aws_kinesisanalyticsv2_application.flink_parquet_writer.name
  snapshot_name    = "${local.flink_application_name}-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # This is a placeholder - snapshots are typically created via AWS Console or CLI
  # after the application is running

  lifecycle {
    ignore_changes = [snapshot_name]
  }
}

# -----------------------------------------------------------------------------
# IMPORTANT NOTES - FLINK APPLICATION DEVELOPMENT
# -----------------------------------------------------------------------------
# 
# ============================================================================
# STEP 1: CREATE FLINK APPLICATION (Java/Scala)
# ============================================================================
# 
# Your Flink application needs to:
# 1. Read from MSK using KafkaSource with IAM authentication
# 2. Deserialize Chargeback records (JSON to POJO)
# 3. Convert to Parquet format (using Avro schema)
# 4. Write to S3 using StreamingFileSink
# 
# See PHASE3_README.md for complete code examples.
# 
# ============================================================================
# STEP 2: BUILD JAR
# ============================================================================
# 
# Maven build (pom.xml):
#   mvn clean package
# 
# Gradle build (build.gradle):
#   gradle clean build
# 
# Output: target/chargeback-parquet-writer-1.0.jar (~150-200 MB with dependencies)
# 
# ============================================================================
# STEP 3: UPLOAD JAR TO S3
# ============================================================================
# 
# aws s3 cp target/chargeback-parquet-writer-1.0.jar \
#   s3://$(terraform output -raw parquet_bucket_name)/flink/applications/chargeback-parquet-writer/application.jar
# 
# ============================================================================
# STEP 4: START FLINK APPLICATION
# ============================================================================
# 
# Via AWS Console:
#   1. Go to Kinesis Data Analytics
#   2. Select your application
#   3. Click "Run"
# 
# Via AWS CLI:
#   aws kinesisanalyticsv2 start-application \
#     --application-name $(terraform output -raw flink_application_name) \
#     --run-configuration '{}'
# 
# ============================================================================
# STEP 5: MONITOR APPLICATION
# ============================================================================
# 
# CloudWatch Logs:
#   /aws/kinesisanalytics/{application-name}
# 
# CloudWatch Metrics:
#   - AWS/KinesisAnalytics
#   - Namespace: {application-name}
#   - Key metrics: KPUs, Uptime, Checkpoints, Backpressure
# 
# Flink Dashboard:
#   Available in AWS Console under "Monitoring" tab
# 
# ============================================================================
# TROUBLESHOOTING
# ============================================================================
# 
# 1. Application won't start:
#    - Check JAR is uploaded to correct S3 path
#    - Verify IAM role has S3 read permissions
#    - Check CloudWatch logs for startup errors
# 
# 2. Can't connect to MSK:
#    - Verify security group allows traffic
#    - Check VPC configuration
#    - Confirm IAM role has kafka-cluster permissions
# 
# 3. Parquet files not appearing:
#    - Check S3 bucket permissions
#    - Verify checkpoint interval (files written on checkpoint)
#    - Look for errors in Flink logs
# 
# 4. High latency:
#    - Increase parallelism
#    - Check MSK partition count
#    - Monitor Flink backpressure metrics
# 
# ============================================================================
# COST OPTIMIZATION
# ============================================================================
# 
# - 1 KPU = 1 vCPU + 4 GB RAM = ~$0.11/hour = ~$80/month
# - Start with parallelism=1 for POC
# - Scale up based on throughput requirements
# - Use auto-scaling in production (requires monitoring)
# 
# ============================================================================
