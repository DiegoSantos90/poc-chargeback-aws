# =============================================================================
# Phase 4 - Lambda Consolidation Updater
# =============================================================================
# This Lambda function consumes consolidation events from Kafka and updates
# DynamoDB chargeback records with consolidation metadata.
# =============================================================================

# -----------------------------------------------------------------------------
# Upload Lambda Deployment Package to S3
# -----------------------------------------------------------------------------

resource "aws_s3_object" "consolidation_updater_lambda" {
  bucket = var.parquet_bucket_name
  key    = "${var.s3_glue_scripts_prefix}/lambda/consolidation-updater.zip"
  source = "${path.module}/../../../../deployments/lambda/consolidation-updater.zip"
  etag   = filemd5("${path.module}/../../../../deployments/lambda/consolidation-updater.zip")
  
  tags = merge(
    local.common_tags,
    {
      Name = "consolidation-updater-lambda-package"
    }
  )
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "consolidation_updater" {
  function_name = "${local.name_prefix}-consolidation-updater"
  description   = "Updates DynamoDB with consolidation metadata from Kafka events"
  
  # Deployment package
  s3_bucket         = var.parquet_bucket_name
  s3_key            = aws_s3_object.consolidation_updater_lambda.key
  s3_object_version = aws_s3_object.consolidation_updater_lambda.version_id
  
  # Runtime configuration
  runtime = "python3.11"
  handler = "lambda_function.lambda_handler"
  timeout = var.consolidation_updater_timeout_seconds
  memory_size = var.consolidation_updater_memory_mb
  
  # IAM role
  role = aws_iam_role.consolidation_updater.arn
  
  # VPC configuration (to access MSK in private subnets)
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.consolidation_updater[0].id]
  }
  
  # Environment variables
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      AWS_REGION          = local.region
      LOG_LEVEL           = var.consolidation_updater_log_level
    }
  }
  
  # Dead letter queue configuration
  dead_letter_config {
    target_arn = var.enable_consolidation_dlq ? aws_sqs_queue.consolidation_dlq[0].arn : null
  }
  
  # Ensure Lambda is created after deployment package is uploaded
  depends_on = [
    aws_s3_object.consolidation_updater_lambda,
    aws_cloudwatch_log_group.consolidation_updater
  ]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-consolidation-updater"
    }
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "consolidation_updater" {
  name              = "/aws/lambda/${local.name_prefix}-consolidation-updater"
  retention_in_days = var.consolidation_log_retention_days
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-consolidation-updater-logs"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM Role for Lambda
# -----------------------------------------------------------------------------

resource "aws_iam_role" "consolidation_updater" {
  name               = "${local.name_prefix}-consolidation-updater-role"
  description        = "IAM role for consolidation updater Lambda function"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-consolidation-updater-role"
    }
  )
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

# Attach AWS managed policy for VPC execution
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.consolidation_updater.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# -----------------------------------------------------------------------------
# IAM Policy - DynamoDB Access
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "consolidation_updater_dynamodb" {
  name   = "${local.name_prefix}-consolidation-updater-dynamodb"
  role   = aws_iam_role.consolidation_updater.id
  policy = data.aws_iam_policy_document.consolidation_updater_dynamodb.json
}

data "aws_iam_policy_document" "consolidation_updater_dynamodb" {
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
    
    actions = [
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    
    resources = [
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.dynamodb_table_name}",
      "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.dynamodb_table_name}/index/*"
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - MSK Access
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "consolidation_updater_msk" {
  name   = "${local.name_prefix}-consolidation-updater-msk"
  role   = aws_iam_role.consolidation_updater.id
  policy = data.aws_iam_policy_document.consolidation_updater_msk.json
}

data "aws_iam_policy_document" "consolidation_updater_msk" {
  # Kafka cluster permissions
  statement {
    sid    = "MSKClusterAccess"
    effect = "Allow"
    
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:DescribeGroup",
      "kafka-cluster:AlterGroup"
    ]
    
    resources = [
      var.msk_cluster_arn
    ]
  }
  
  # Kafka topic permissions (read-only)
  statement {
    sid    = "MSKTopicRead"
    effect = "Allow"
    
    actions = [
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:ReadData"
    ]
    
    resources = [
      "arn:aws:kafka:${local.region}:${local.account_id}:topic/${split("/", var.msk_cluster_arn)[1]}/${var.kafka_consolidation_topic}"
    ]
  }
  
  # Kafka consumer group permissions
  statement {
    sid    = "MSKConsumerGroup"
    effect = "Allow"
    
    actions = [
      "kafka-cluster:AlterGroup",
      "kafka-cluster:DescribeGroup"
    ]
    
    resources = [
      "arn:aws:kafka:${local.region}:${local.account_id}:group/${split("/", var.msk_cluster_arn)[1]}/*"
    ]
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - CloudWatch Logs and Metrics
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "consolidation_updater_cloudwatch" {
  name   = "${local.name_prefix}-consolidation-updater-cloudwatch"
  role   = aws_iam_role.consolidation_updater.id
  policy = data.aws_iam_policy_document.consolidation_updater_cloudwatch.json
}

data "aws_iam_policy_document" "consolidation_updater_cloudwatch" {
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.name_prefix}-consolidation-updater:*"
    ]
  }
  
  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"
    
    actions = [
      "cloudwatch:PutMetricData"
    ]
    
    resources = ["*"]
    
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["POC-Chargeback/ConsolidationUpdater"]
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Policy - DLQ Access
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "consolidation_updater_dlq" {
  count = var.enable_consolidation_dlq ? 1 : 0
  
  name   = "${local.name_prefix}-consolidation-updater-dlq"
  role   = aws_iam_role.consolidation_updater.id
  policy = data.aws_iam_policy_document.consolidation_updater_dlq[0].json
}

data "aws_iam_policy_document" "consolidation_updater_dlq" {
  count = var.enable_consolidation_dlq ? 1 : 0
  
  statement {
    sid    = "SendToDLQ"
    effect = "Allow"
    
    actions = [
      "sqs:SendMessage"
    ]
    
    resources = [
      aws_sqs_queue.consolidation_dlq[0].arn
    ]
  }
}

# -----------------------------------------------------------------------------
# Security Group for Lambda
# -----------------------------------------------------------------------------

resource "aws_security_group" "consolidation_updater" {
  count = var.enable_kafka_notifications ? 1 : 0
  
  name        = "${local.name_prefix}-consolidation-updater-sg"
  description = "Security group for consolidation updater Lambda function"
  vpc_id      = var.vpc_id
  
  # Outbound to MSK (port 9098 for IAM authentication)
  egress {
    description     = "MSK Kafka (IAM auth)"
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [var.msk_security_group_id]
  }
  
  # Outbound HTTPS for DynamoDB via VPC endpoint
  egress {
    description = "HTTPS for DynamoDB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-consolidation-updater-sg"
    }
  )
}

# Add ingress rule to MSK security group to allow Lambda access
resource "aws_security_group_rule" "msk_allow_lambda" {
  count = var.enable_kafka_notifications ? 1 : 0
  
  type                     = "ingress"
  description              = "Allow Lambda consolidation updater"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  security_group_id        = var.msk_security_group_id
  source_security_group_id = aws_security_group.consolidation_updater[0].id
}

# -----------------------------------------------------------------------------
# MSK Event Source Mapping
# -----------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "msk_consolidation_events" {
  event_source_arn  = var.msk_cluster_arn
  function_name     = aws_lambda_function.consolidation_updater.arn
  topics            = [var.kafka_consolidation_topic]
  starting_position = "TRIM_HORIZON"  # Process all available messages
  
  # Batch configuration
  batch_size                         = 100
  maximum_batching_window_in_seconds = 5
  
  # Enable partial batch failure support
  function_response_types = ["ReportBatchItemFailures"]
  
  # Source access configuration for IAM authentication
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = var.private_subnet_ids[0]
  }
  
  source_access_configuration {
    type = "VPC_SUBNET"
    uri  = var.private_subnet_ids[1]
  }
  
  source_access_configuration {
    type = "VPC_SECURITY_GROUP"
    uri  = aws_security_group.consolidation_updater[0].id
  }
  
  # Error handling
  destination_config {
    on_failure {
      destination_arn = var.enable_consolidation_dlq ? aws_sqs_queue.consolidation_dlq[0].arn : null
    }
  }
  
  depends_on = [
    aws_iam_role_policy.consolidation_updater_msk,
    aws_iam_role_policy_attachment.lambda_vpc_execution
  ]
}

# -----------------------------------------------------------------------------
# Dead Letter Queue (Optional)
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "consolidation_dlq" {
  count = var.enable_consolidation_dlq ? 1 : 0
  
  name                      = "${local.name_prefix}-consolidation-dlq"
  message_retention_seconds = 1209600  # 14 days
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-consolidation-dlq"
    }
  )
}

# -----------------------------------------------------------------------------
# CloudWatch Alarms
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-consolidation-updater-errors"
  alarm_description   = "Consolidation updater Lambda errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.consolidation_updater.function_name
  }
  
  alarm_actions = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.glue_alerts[0].arn] : []
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-consolidation-updater-duration"
  alarm_description   = "Consolidation updater Lambda approaching timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.consolidation_updater_timeout_seconds * 1000 * 0.8  # 80% of timeout
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.consolidation_updater.function_name
  }
  
  alarm_actions = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.glue_alerts[0].arn] : []
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.enable_consolidation_dlq && var.enable_cloudwatch_alarms ? 1 : 0
  
  alarm_name          = "${local.name_prefix}-consolidation-dlq-messages"
  alarm_description   = "Messages in consolidation DLQ"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    QueueName = aws_sqs_queue.consolidation_dlq[0].name
  }
  
  alarm_actions = var.enable_cloudwatch_alarms && length(var.alarm_email_endpoints) > 0 ? [aws_sns_topic.glue_alerts[0].arn] : []
  
  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "consolidation_updater_lambda_arn" {
  description = "ARN of consolidation updater Lambda function"
  value       = aws_lambda_function.consolidation_updater.arn
}

output "consolidation_updater_lambda_name" {
  description = "Name of consolidation updater Lambda function"
  value       = aws_lambda_function.consolidation_updater.function_name
}

output "consolidation_updater_log_group" {
  description = "CloudWatch log group name for consolidation updater"
  value       = aws_cloudwatch_log_group.consolidation_updater.name
}

output "consolidation_updater_role_arn" {
  description = "IAM role ARN for consolidation updater Lambda"
  value       = aws_iam_role.consolidation_updater.arn
}

output "consolidation_updater_dlq_url" {
  description = "DLQ URL for failed consolidation events"
  value       = var.enable_consolidation_dlq ? aws_sqs_queue.consolidation_dlq[0].url : null
}

output "consolidation_updater_security_group_id" {
  description = "Security group ID for consolidation updater Lambda"
  value       = var.enable_kafka_notifications ? aws_security_group.consolidation_updater[0].id : null
}
