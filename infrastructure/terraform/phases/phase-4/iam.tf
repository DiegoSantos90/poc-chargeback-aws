# =============================================================================
# Phase 4 - IAM Roles and Policies
# =============================================================================
# This file creates IAM roles and policies for:
# 1. AWS Glue (Crawler and ETL Job)
# 2. EventBridge Scheduler (to trigger Glue ETL)
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role - AWS Glue Service
# -----------------------------------------------------------------------------

resource "aws_iam_role" "glue" {
  name               = local.glue_iam_role_name
  description        = "IAM role for Glue crawler and ETL jobs in Phase 4"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json
  
  tags = merge(
    local.common_tags,
    {
      Name = local.glue_iam_role_name
    }
  )
}

# Assume role policy for Glue service
data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - Glue Service Policy (AWS Managed)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# -----------------------------------------------------------------------------
# IAM Policy - S3 Access for Glue
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "glue_s3_access" {
  name   = "${local.glue_iam_role_name}-s3-access"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_s3_access.json
}

data "aws_iam_policy_document" "glue_s3_access" {
  # Read from landing zone
  statement {
    sid    = "ReadLandingZone"
    effect = "Allow"
    
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    
    resources = [
      var.parquet_bucket_arn,
      "${var.parquet_bucket_arn}/${var.s3_landing_prefix}/*"
    ]
  }
  
  # Write to consolidated zone
  statement {
    sid    = "WriteConsolidated"
    effect = "Allow"
    
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject"
    ]
    
    resources = [
      "${var.parquet_bucket_arn}/${var.s3_consolidated_prefix}/*"
    ]
  }
  
  # Access to Glue scripts
  statement {
    sid    = "AccessGlueScripts"
    effect = "Allow"
    
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    
    resources = [
      "${var.parquet_bucket_arn}/${var.s3_glue_scripts_prefix}/*"
    ]
  }
  
  # Access to Glue temp directory
  statement {
    sid    = "AccessGlueTemp"
    effect = "Allow"
    
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    
    resources = [
      "${var.parquet_bucket_arn}/${var.s3_glue_temp_prefix}/*"
    ]
  }
  
  # Access to Spark logs
  statement {
    sid    = "WriteSparkLogs"
    effect = "Allow"
    
    actions = [
      "s3:PutObject"
    ]
    
    resources = [
      "${var.parquet_bucket_arn}/${var.s3_glue_spark_logs_prefix}/*"
    ]
  }
  
  # List bucket capability
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    
    resources = [
      var.parquet_bucket_arn
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - CloudWatch Logs for Glue
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "glue_cloudwatch_logs" {
  name   = "${local.glue_iam_role_name}-cloudwatch-logs"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_cloudwatch_logs.json
}

data "aws_iam_policy_document" "glue_cloudwatch_logs" {
  statement {
    effect = "Allow"
    
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws-glue/*"
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - MSK/Kafka Access for Glue
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "glue_msk_access" {
  count = local.kafka_enabled ? 1 : 0
  
  name   = "${local.glue_iam_role_name}-msk-access"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_msk_access[0].json
}

data "aws_iam_policy_document" "glue_msk_access" {
  count = local.kafka_enabled ? 1 : 0
  
  # Kafka Cluster permissions
  statement {
    sid    = "MSKClusterAccess"
    effect = "Allow"
    
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:AlterCluster",
      "kafka-cluster:DescribeCluster"
    ]
    
    resources = [
      var.msk_cluster_arn
    ]
  }
  
  # Kafka Topic permissions
  statement {
    sid    = "MSKTopicAccess"
    effect = "Allow"
    
    actions = [
      "kafka-cluster:CreateTopic",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:WriteData",
      "kafka-cluster:ReadData"
    ]
    
    resources = [
      "arn:aws:kafka:${local.region}:${local.account_id}:topic/${split("/", var.msk_cluster_arn)[1]}/*"
    ]
  }
  
  # Kafka Group permissions (for consumer groups)
  statement {
    sid    = "MSKGroupAccess"
    effect = "Allow"
    
    actions = [
      "kafka-cluster:AlterGroup",
      "kafka-cluster:DescribeGroup"
    ]
    
    resources = [
      "arn:aws:kafka:${local.region}:${local.account_id}:group/${split("/", var.msk_cluster_arn)[1]}/*"
    ]
  }
  
  # EC2 permissions for VPC access
  statement {
    sid    = "VPCAccess"
    effect = "Allow"
    
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]
    
    resources = ["*"]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - Glue Data Catalog Access
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "glue_catalog_access" {
  name   = "${local.glue_iam_role_name}-catalog-access"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_catalog_access.json
}

data "aws_iam_policy_document" "glue_catalog_access" {
  statement {
    effect = "Allow"
    
    actions = [
      "glue:GetDatabase",
      "glue:GetTable",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:CreatePartition",
      "glue:BatchCreatePartition",
      "glue:UpdatePartition",
      "glue:DeletePartition",
      "glue:BatchDeletePartition"
    ]
    
    resources = [
      "arn:aws:glue:${local.region}:${local.account_id}:catalog",
      "arn:aws:glue:${local.region}:${local.account_id}:database/${local.glue_database_name}",
      "arn:aws:glue:${local.region}:${local.account_id}:table/${local.glue_database_name}/*"
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM Role - EventBridge Scheduler
# -----------------------------------------------------------------------------

resource "aws_iam_role" "eventbridge_scheduler" {
  name               = "${local.eventbridge_scheduler_name}-role"
  description        = "IAM role for EventBridge Scheduler to trigger Glue ETL jobs"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.eventbridge_scheduler_name}-role"
    }
  )
}

# Assume role policy for EventBridge Scheduler
data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
    
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - EventBridge Start Glue Job
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "eventbridge_start_glue" {
  name   = "${local.eventbridge_scheduler_name}-start-glue"
  role   = aws_iam_role.eventbridge_scheduler.id
  policy = data.aws_iam_policy_document.eventbridge_start_glue.json
}

data "aws_iam_policy_document" "eventbridge_start_glue" {
  statement {
    effect = "Allow"
    
    actions = [
      "glue:StartJobRun"
    ]
    
    resources = [
      "arn:aws:glue:${local.region}:${local.account_id}:job/${local.glue_job_name}"
    ]
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "glue_role_name" {
  description = "Name of the Glue IAM role"
  value       = aws_iam_role.glue.name
}

output "glue_role_arn" {
  description = "ARN of the Glue IAM role"
  value       = aws_iam_role.glue.arn
}

output "eventbridge_scheduler_role_arn" {
  description = "ARN of the EventBridge Scheduler IAM role"
  value       = aws_iam_role.eventbridge_scheduler.arn
}
