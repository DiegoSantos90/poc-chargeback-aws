# =============================================================================
# Phase 3 - IAM Roles and Policies
# =============================================================================
# This file creates IAM roles and policies for:
# 1. Lambda Stream Processor (DynamoDB Streams + MSK Producer)
# 2. Kinesis Data Analytics Flink Application (MSK Consumer + S3 Writer)
# =============================================================================

# -----------------------------------------------------------------------------
# Lambda Stream Processor IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_stream_processor" {
  name = "${local.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.lambda_function_name}-role"
    }
  )
}

# Policy 1: VPC Execution (for Lambda in VPC)
resource "aws_iam_role_policy" "lambda_vpc_execution" {
  name = "vpc-execution"
  role = aws_iam_role.lambda_stream_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy 2: CloudWatch Logs
resource "aws_iam_role_policy" "lambda_cloudwatch_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.lambda_stream_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:${local.lambda_log_group_name}:*"
      }
    ]
  })
}

# Policy 3: DynamoDB Streams Read
resource "aws_iam_role_policy" "lambda_dynamodb_streams" {
  name = "dynamodb-streams"
  role = aws_iam_role.lambda_stream_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Resource = var.dynamodb_stream_arn
      }
    ]
  })
}

# Policy 4: MSK Producer (IAM authentication)
resource "aws_iam_role_policy" "lambda_msk_producer" {
  name = "msk-producer"
  role = aws_iam_role.lambda_stream_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_serverless_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:WriteData"
        ]
        Resource = "arn:aws:kafka:${local.region}:${local.account_id}:topic/${local.msk_cluster_name}/*/${var.kafka_topic_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "arn:aws:kafka:${local.region}:${local.account_id}:group/${local.msk_cluster_name}/*/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Kinesis Data Analytics (Flink) IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "flink_application" {
  name = "${local.flink_application_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "kinesisanalytics.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.flink_application_name}-role"
    }
  )
}

# Policy 1: MSK Consumer (IAM authentication)
resource "aws_iam_role_policy" "flink_msk_consumer" {
  name = "msk-consumer"
  role = aws_iam_role.flink_application.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:DescribeClusterDynamicConfiguration"
        ]
        Resource = aws_msk_serverless_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:ReadData"
        ]
        Resource = "arn:aws:kafka:${local.region}:${local.account_id}:topic/${local.msk_cluster_name}/*/${var.kafka_topic_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = "arn:aws:kafka:${local.region}:${local.account_id}:group/${local.msk_cluster_name}/*/*"
      }
    ]
  })
}

# Policy 2: S3 Write Access (for Parquet output)
resource "aws_iam_role_policy" "flink_s3_write" {
  name = "s3-write"
  role = aws_iam_role.flink_application.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.parquet_bucket_arn}/${local.parquet_output_prefix}/*",
          "${var.parquet_bucket_arn}/${local.flink_checkpoint_prefix}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.parquet_bucket_arn
      }
    ]
  })
}

# Policy 3: S3 Read Access (for application JAR)
resource "aws_iam_role_policy" "flink_s3_read_jar" {
  name = "s3-read-jar"
  role = aws_iam_role.flink_application.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.parquet_bucket_arn}/${local.flink_application_jar_key}"
      }
    ]
  })
}

# Policy 4: CloudWatch Logs
resource "aws_iam_role_policy" "flink_cloudwatch_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.flink_application.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:${local.flink_log_group_name}:*"
      }
    ]
  })
}

# Policy 5: VPC Access (for Flink to access MSK in VPC)
resource "aws_iam_role_policy" "flink_vpc_access" {
  name = "vpc-access"
  role = aws_iam_role.flink_application.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy 6: CloudWatch Metrics
resource "aws_iam_role_policy" "flink_cloudwatch_metrics" {
  name = "cloudwatch-metrics"
  role = aws_iam_role.flink_application.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}
