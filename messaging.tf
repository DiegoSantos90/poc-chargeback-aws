# SQS Queue for processing requests
resource "aws_sqs_queue" "chargeback_processing" {
  name                      = "${var.project_name}-processing-${var.environment}"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20
  visibility_timeout_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.common_tags
}

# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name = "${var.project_name}-dlq-${var.environment}"
  tags = local.common_tags
}

# SNS Topic for notifications
resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-notifications-${var.environment}"
  tags = local.common_tags
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
  tags = local.common_tags
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "chargeback_processing" {
  queue_url = aws_sqs_queue.chargeback_processing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.chargeback_processing.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.raw_data.arn
          }
        }
      }
    ]
  })
}