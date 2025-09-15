# Output values
output "raw_data_bucket" {
  description = "S3 bucket for raw chargeback data"
  value       = aws_s3_bucket.raw_data.bucket
}

output "processed_csvs_bucket" {
  description = "S3 bucket for processed CSV files"
  value       = aws_s3_bucket.processed_csvs.bucket
}

output "step_function_arn" {
  description = "ARN of the chargeback processing Step Function"
  value       = aws_sfn_state_machine.chargeback_processing.arn
}

output "notification_topic_arn" {
  description = "ARN of the SNS notification topic"
  value       = aws_sns_topic.notifications.arn
}

output "alerts_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "lambda_functions" {
  description = "Lambda function ARNs"
  value = {
    data_processor = aws_lambda_function.data_processor.arn
    csv_generator  = aws_lambda_function.csv_generator.arn
    ftp_uploader   = aws_lambda_function.ftp_uploader.arn
  }
}

output "sqs_queue_url" {
  description = "URL of the SQS processing queue"
  value       = aws_sqs_queue.chargeback_processing.url
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.chargeback_monitoring.dashboard_name}"
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret for FTP credentials"
  value       = aws_secretsmanager_secret.ftp_credentials.name
}