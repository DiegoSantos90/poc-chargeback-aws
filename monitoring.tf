# Secrets Manager for FTP credentials
resource "aws_secretsmanager_secret" "ftp_credentials" {
  name        = "${var.project_name}-ftp-credentials-${var.environment}"
  description = "FTP credentials for card company file delivery"
  
  tags = local.common_tags
}

# Secret version with placeholder values
resource "aws_secretsmanager_secret_version" "ftp_credentials" {
  secret_id = aws_secretsmanager_secret.ftp_credentials.id
  secret_string = jsonencode({
    host      = "ftp.cardcompany.com"
    username  = "chargeback_user"
    password  = "CHANGE_ME_IN_PRODUCTION"
    port      = "21"
    directory = "/chargebacks"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "chargeback_monitoring" {
  dashboard_name = "${var.project_name}-monitoring-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.data_processor.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.csv_generator.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.ftp_uploader.function_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Duration"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.data_processor.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.csv_generator.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.ftp_uploader.function_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/States", "ExecutionSucceeded", "StateMachineArn", aws_sfn_state_machine.chargeback_processing.arn],
            ["AWS/States", "ExecutionFailed", "StateMachineArn", aws_sfn_state_machine.chargeback_processing.arn]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Step Functions Executions"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    "data-processor" = aws_lambda_function.data_processor.function_name
    "csv-generator"  = aws_lambda_function.csv_generator.function_name
    "ftp-uploader"   = aws_lambda_function.ftp_uploader.function_name
  }

  alarm_name          = "${var.project_name}-${each.key}-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors ${each.key} lambda errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "step_function_failures" {
  alarm_name          = "${var.project_name}-step-function-failures-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors step function execution failures"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.chargeback_processing.arn
  }

  tags = local.common_tags
}