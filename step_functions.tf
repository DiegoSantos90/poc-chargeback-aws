# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/stepfunctions/${var.project_name}-processing-${var.environment}"
  retention_in_days = 14
  tags              = local.common_tags
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "chargeback_processing" {
  name     = "${var.project_name}-processing-${var.environment}"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "Chargeback processing workflow"
    StartAt = "ProcessData"
    States = {
      ProcessData = {
        Type     = "Task"
        Resource = aws_lambda_function.data_processor.arn
        Next     = "GenerateCSVs"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "NotifyFailure"
            ResultPath  = "$.error"
          }
        ]
      }
      GenerateCSVs = {
        Type     = "Task"
        Resource = aws_lambda_function.csv_generator.arn
        Next     = "UploadToFTP"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "NotifyFailure"
            ResultPath  = "$.error"
          }
        ]
      }
      UploadToFTP = {
        Type     = "Task"
        Resource = aws_lambda_function.ftp_uploader.arn
        Next     = "NotifySuccess"
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException"]
            IntervalSeconds = 5
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.TaskFailed"]
            Next        = "NotifyFailure"
            ResultPath  = "$.error"
          }
        ]
      }
      NotifySuccess = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.notifications.arn
          Message = {
            "status" = "SUCCESS"
            "message" = "Chargeback processing completed successfully"
            "execution_arn.$" = "$$.Execution.Name"
            "timestamp.$" = "$$.Execution.StartTime"
          }
        }
        End = true
      }
      NotifyFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.alerts.arn
          Message = {
            "status" = "FAILED"
            "message" = "Chargeback processing failed"
            "error.$" = "$.error"
            "execution_arn.$" = "$$.Execution.Name"
            "timestamp.$" = "$$.Execution.StartTime"
          }
        }
        End = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = local.common_tags
}