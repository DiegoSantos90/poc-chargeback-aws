# =============================================================================
# Phase 3 - Lambda Stream Processor (Python 3)
# =============================================================================
# This Lambda function processes DynamoDB Streams and publishes events to MSK.
# It reads change events from DynamoDB and forwards them to Kafka topics.
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group for Lambda
# -----------------------------------------------------------------------------

resource "aws_security_group" "lambda_stream_processor" {
  name        = local.lambda_security_group_name
  description = "Security group for Lambda stream processor"
  vpc_id      = var.vpc_id

  # Allow HTTPS for AWS API calls
  egress {
    description = "HTTPS for AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow DNS resolution
  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.lambda_security_group_name
    }
  )
}

# Security Group Rules to allow Lambda access to MSK
# (created separately to avoid circular dependency)
resource "aws_security_group_rule" "lambda_to_msk_9092" {
  type                     = "egress"
  description              = "MSK Kafka plaintext"
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msk.id
  security_group_id        = aws_security_group.lambda_stream_processor.id
}

resource "aws_security_group_rule" "lambda_to_msk_9098" {
  type                     = "egress"
  description              = "MSK IAM authentication"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.msk.id
  security_group_id        = aws_security_group.lambda_stream_processor.id
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

resource "aws_lambda_function" "stream_processor" {
  function_name = local.lambda_function_name
  description   = "Processes DynamoDB Streams and publishes to MSK Kafka"
  role          = aws_iam_role.lambda_stream_processor.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  # Deployment package
  filename         = local.lambda_zip_path
  source_code_hash = filebase64sha256(local.lambda_zip_path)

  # VPC Configuration (required to access MSK)
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_stream_processor.id]
  }

  # Environment variables
  environment {
    variables = {
      MSK_BOOTSTRAP_SERVERS = aws_msk_serverless_cluster.main.bootstrap_brokers_sasl_iam
      KAFKA_TOPIC           = var.kafka_topic_name
      AWS_REGION            = local.region
      LOG_LEVEL             = var.environment == "dev" ? "DEBUG" : "INFO"
      DYNAMODB_TABLE_NAME   = var.dynamodb_table_name
    }
  }

  # Tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # Dead Letter Queue (optional)
  dynamic "dead_letter_config" {
    for_each = var.enable_dlq ? [1] : []
    content {
      target_arn = aws_sqs_queue.lambda_dlq[0].arn
    }
  }

  # Reserved concurrent executions (optional)
  reserved_concurrent_executions = var.environment == "prod" ? 10 : -1

  tags = merge(
    local.common_tags,
    {
      Name = local.lambda_function_name
    }
  )

  depends_on = [
    aws_iam_role_policy.lambda_vpc_execution,
    aws_iam_role_policy.lambda_cloudwatch_logs,
    aws_cloudwatch_log_group.lambda
  ]
}

# -----------------------------------------------------------------------------
# DynamoDB Stream Event Source Mapping
# -----------------------------------------------------------------------------

resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  event_source_arn          = var.dynamodb_stream_arn
  function_name             = aws_lambda_function.stream_processor.arn
  starting_position         = "LATEST" # LATEST or TRIM_HORIZON
  batch_size                = var.lambda_batch_size
  parallelization_factor    = var.lambda_parallelization_factor
  maximum_batching_window_in_seconds = 5
  maximum_retry_attempts    = var.lambda_retry_attempts
  maximum_record_age_in_seconds = var.lambda_maximum_record_age
  bisect_batch_on_function_error = true

  # Destination for failed records (optional)
  dynamic "destination_config" {
    for_each = var.enable_dlq ? [1] : []
    content {
      on_failure {
        destination_arn = aws_sqs_queue.lambda_dlq[0].arn
      }
    }
  }

  # Filter patterns (optional - only process specific events)
  # filter_criteria {
  #   filter {
  #     pattern = jsonencode({
  #       eventName = ["INSERT", "MODIFY"]
  #     })
  #   }
  # }

  depends_on = [
    aws_iam_role_policy.lambda_dynamodb_streams,
    aws_iam_role_policy.lambda_msk_producer
  ]
}

# -----------------------------------------------------------------------------
# Dead Letter Queue (Optional)
# -----------------------------------------------------------------------------

resource "aws_sqs_queue" "lambda_dlq" {
  count = var.enable_dlq ? 1 : 0

  name                       = "${local.lambda_function_name}-dlq"
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 300

  tags = merge(
    local.common_tags,
    {
      Name = "${local.lambda_function_name}-dlq"
    }
  )
}

resource "aws_sqs_queue_policy" "lambda_dlq" {
  count     = var.enable_dlq ? 1 : 0
  queue_url = aws_sqs_queue.lambda_dlq[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.lambda_dlq[0].arn
      }
    ]
  })
}

# Add SQS permissions to Lambda role
resource "aws_iam_role_policy" "lambda_dlq_send" {
  count = var.enable_dlq ? 1 : 0
  name  = "dlq-send"
  role  = aws_iam_role.lambda_stream_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.lambda_dlq[0].arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda Insights (Optional Enhanced Monitoring)
# -----------------------------------------------------------------------------

resource "aws_lambda_layer_version" "lambda_insights" {
  count = var.enable_lambda_insights ? 1 : 0

  layer_name          = "LambdaInsightsExtension"
  compatible_runtimes = [var.lambda_runtime]

  # This would typically reference a Lambda Insights layer ARN
  # For now, this is a placeholder
  # Real ARN format: arn:aws:lambda:region:580247275435:layer:LambdaInsightsExtension:version
}

# -----------------------------------------------------------------------------
# IMPORTANT NOTES
# -----------------------------------------------------------------------------
# 
# 1. DEPLOYMENT PACKAGE:
#    Before deploying, create the Lambda deployment package:
#    
#    cd deployments/lambda/stream-processor
#    pip install -r requirements.txt -t .
#    zip -r ../stream-processor.zip .
#    
# 2. REQUIRED PYTHON PACKAGES:
#    - kafka-python (or aiokafka for async)
#    - aws-msk-iam-sasl-signer-python (for MSK IAM auth)
#    - boto3 (already included in Lambda runtime)
#    
# 3. SAMPLE LAMBDA CODE:
#    See PHASE3_README.md for complete Python implementation example
#    
# 4. MSK TOPIC CREATION:
#    The Kafka topic must be created before Lambda can publish.
#    See msk.tf for topic creation instructions.
#    
# 5. COLD START:
#    First invocation will be slow (~2-5 seconds) due to VPC ENI creation
#    Subsequent invocations: <100ms
#    
# 6. MONITORING:
#    - CloudWatch Logs: /aws/lambda/{function-name}
#    - CloudWatch Metrics: Lambda namespace
#    - DLQ: Check SQS queue for failed records
# =============================================================================
