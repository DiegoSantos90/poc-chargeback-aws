# ============================================================================
# Phase 2: Outputs
# ============================================================================
# Outputs exportam valores importantes após o deploy

# ----------------------------------------------------------------------------
# API Gateway Outputs
# ----------------------------------------------------------------------------

output "api_gateway_url" {
  description = "Base URL of the API Gateway"
  value       = "${aws_api_gateway_stage.main.invoke_url}"
  
  # Exemplo: https://abc123.execute-api.sa-east-1.amazonaws.com/dev
}

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway (for Lambda permissions)"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

# ----------------------------------------------------------------------------
# Lambda Outputs
# ----------------------------------------------------------------------------

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.api_handler.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.api_handler.arn
}

output "lambda_function_version" {
  description = "Latest published version of the Lambda function"
  value       = aws_lambda_function.api_handler.version
}

output "lambda_alias_name" {
  description = "Name of the Lambda alias"
  value       = aws_lambda_alias.live.name
}

output "lambda_alias_arn" {
  description = "ARN of the Lambda alias (used by API Gateway)"
  value       = aws_lambda_alias.live.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda alias"
  value       = aws_lambda_alias.live.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

# ----------------------------------------------------------------------------
# Security Group Outputs
# ----------------------------------------------------------------------------

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda.id
}

# ----------------------------------------------------------------------------
# CloudWatch Logs Outputs
# ----------------------------------------------------------------------------

output "lambda_log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "api_gateway_log_group_name" {
  description = "Name of the API Gateway CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway.name
}

output "api_gateway_execution_log_group_name" {
  description = "Name of the API Gateway execution CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway_execution.name
}

# ----------------------------------------------------------------------------
# Summary Output (útil para mostrar após deploy)
# ----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    api_url             = "${aws_api_gateway_stage.main.invoke_url}"
    lambda_function     = aws_lambda_function.api_handler.function_name
    lambda_version      = aws_lambda_function.api_handler.version
    lambda_alias        = aws_lambda_alias.live.name
    environment         = var.environment
    aws_region          = var.aws_region
    
    # Comandos úteis
    curl_example        = "curl ${aws_api_gateway_stage.main.invoke_url}/health"
    
    view_logs_lambda    = "aws logs tail ${aws_cloudwatch_log_group.lambda.name} --follow"
    
    view_logs_api       = "aws logs tail ${aws_cloudwatch_log_group.api_gateway.name} --follow"
    
    rollback_command    = "aws lambda update-alias --function-name ${aws_lambda_function.api_handler.function_name} --name ${aws_lambda_alias.live.name} --function-version <VERSION>"
    
    list_versions       = "aws lambda list-versions-by-function --function-name ${aws_lambda_function.api_handler.function_name}"
  }
}

# ============================================================================
# COMO USAR OS OUTPUTS:
# ============================================================================
#
# 1. Ver todos os outputs após o deploy:
#    terraform output
#
# 2. Ver output específico:
#    terraform output api_gateway_url
#
# 3. Usar output em JSON (útil para scripts):
#    terraform output -json deployment_summary | jq .
#
# 4. Testar a API:
#    curl $(terraform output -raw api_gateway_url)/health
#
# 5. Ver logs da Lambda em tempo real:
#    aws logs tail $(terraform output -raw lambda_log_group_name) --follow
#
# 6. Ver logs do API Gateway em tempo real:
#    aws logs tail $(terraform output -raw api_gateway_log_group_name) --follow
#
# ============================================================================
# EXEMPLOS DE REQUESTS:
# ============================================================================
#
# URL base (substitua pelo seu):
# export API_URL=$(terraform output -raw api_gateway_url)
#
# Health check:
# curl $API_URL/health
#
# Listar chargebacks:
# curl $API_URL/chargebacks
#
# Criar chargeback:
# curl -X POST $API_URL/chargebacks \
#   -H "Content-Type: application/json" \
#   -d '{
#     "merchant_id": "merch_123",
#     "amount": 150.00,
#     "currency": "USD",
#     "reason": "Product not received"
#   }'
#
# Buscar chargeback específico:
# curl $API_URL/chargebacks/cb_123456
#
# Atualizar chargeback:
# curl -X PUT $API_URL/chargebacks/cb_123456 \
#   -H "Content-Type: application/json" \
#   -d '{
#     "status": "approved"
#   }'
#
# ============================================================================
