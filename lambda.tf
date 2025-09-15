# Archive Lambda function source code
data "archive_file" "data_processor" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/data_processor.py"
  output_path = "${path.module}/lambda_functions/data_processor.zip"
}

data "archive_file" "csv_generator" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/csv_generator.py"
  output_path = "${path.module}/lambda_functions/csv_generator.zip"
}

data "archive_file" "ftp_uploader" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/ftp_uploader.py"
  output_path = "${path.module}/lambda_functions/ftp_uploader.zip"
}

# Lambda function: Data Processor
resource "aws_lambda_function" "data_processor" {
  filename         = data.archive_file.data_processor.output_path
  function_name    = "${var.project_name}-data-processor-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "data_processor.lambda_handler"
  source_code_hash = data.archive_file.data_processor.output_base64sha256
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT_NAME = var.project_name
      SQS_QUEUE_URL = aws_sqs_queue.chargeback_processing.url
    }
  }

  tags = local.common_tags
}

# Lambda function: CSV Generator
resource "aws_lambda_function" "csv_generator" {
  filename         = data.archive_file.csv_generator.output_path
  function_name    = "${var.project_name}-csv-generator-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "csv_generator.lambda_handler"
  source_code_hash = data.archive_file.csv_generator.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT_NAME = var.project_name
      MAX_CSV_FILES = var.max_csv_files
      OUTPUT_BUCKET = aws_s3_bucket.processed_csvs.bucket
    }
  }

  tags = local.common_tags
}

# Lambda function: FTP Uploader
resource "aws_lambda_function" "ftp_uploader" {
  filename         = data.archive_file.ftp_uploader.output_path
  function_name    = "${var.project_name}-ftp-uploader-${var.environment}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "ftp_uploader.lambda_handler"
  source_code_hash = data.archive_file.ftp_uploader.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      ENVIRONMENT = var.environment
      PROJECT_NAME = var.project_name
      FTP_SECRET_NAME = aws_secretsmanager_secret.ftp_credentials.name
      NOTIFICATION_TOPIC_ARN = aws_sns_topic.notifications.arn
    }
  }

  tags = local.common_tags
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "data_processor" {
  name              = "/aws/lambda/${aws_lambda_function.data_processor.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "csv_generator" {
  name              = "/aws/lambda/${aws_lambda_function.csv_generator.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "ftp_uploader" {
  name              = "/aws/lambda/${aws_lambda_function.ftp_uploader.function_name}"
  retention_in_days = 14
  tags              = local.common_tags
}

# S3 bucket notification to trigger Lambda
resource "aws_s3_bucket_notification" "raw_data_notification" {
  bucket = aws_s3_bucket.raw_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.data_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Lambda permission for S3 to invoke function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_data.arn
}