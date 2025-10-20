# ============================================================================
# Phase 2: CloudWatch Log Groups
# ============================================================================
# Log Groups armazenam logs da Lambda e API Gateway

# ----------------------------------------------------------------------------
# Lambda Function Log Group
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.api_handler.function_name}"
  retention_in_days = var.log_retention_days # Default: 1 dia
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-lambda-logs-${var.environment}"
      Environment = var.environment
    }
  )
}

# IMPORTANTE:
# - Nome DEVE seguir o padrão /aws/lambda/{function_name}
# - Lambda automaticamente escreve neste log group
# - Retention: logs são deletados após N dias (economiza custos)

# ----------------------------------------------------------------------------
# API Gateway Access Log Group
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-api-${var.environment}"
  retention_in_days = var.log_retention_days # Default: 1 dia
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-api-gateway-logs-${var.environment}"
      Environment = var.environment
    }
  )
}

# LOGS CAPTURADOS:
# ----------------
# - IP do cliente
# - Timestamp da request
# - Método HTTP e path
# - Status code da response
# - Tempo de resposta
# - User agent

# ----------------------------------------------------------------------------
# API Gateway Execution Log Group (opcional, para debug detalhado)
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "api_gateway_execution" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.main.id}/${var.api_gateway_stage_name}"
  retention_in_days = var.log_retention_days
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-api-gateway-execution-logs-${var.environment}"
      Environment = var.environment
    }
  )
}

# LOGS DE EXECUÇÃO:
# -----------------
# - Detalhes da integração com Lambda
# - Transformações de request/response
# - Erros de autorização
# - Útil para debug (verbose)

# ============================================================================
# LOG INSIGHTS QUERIES (exemplos úteis):
# ============================================================================
#
# 1. LAMBDA: Encontrar erros:
# ----------------------------
# fields @timestamp, @message
# | filter @message like /ERROR/
# | sort @timestamp desc
# | limit 20
#
# 2. LAMBDA: Tempo de execução por request:
# ------------------------------------------
# fields @timestamp, @duration
# | stats avg(@duration), max(@duration), min(@duration)
#
# 3. LAMBDA: Cold starts:
# -----------------------
# fields @timestamp, @initDuration
# | filter ispresent(@initDuration)
# | stats count() as coldStarts, avg(@initDuration) as avgColdStart
#
# 4. API GATEWAY: Requests por status code:
# ------------------------------------------
# fields @timestamp, status
# | stats count() by status
#
# 5. API GATEWAY: Top 10 IPs com mais requests:
# ----------------------------------------------
# fields ip
# | stats count() as requestCount by ip
# | sort requestCount desc
# | limit 10
#
# 6. API GATEWAY: Rotas mais lentas:
# -----------------------------------
# fields resourcePath, @timestamp
# | stats avg(@duration) as avgLatency by resourcePath
# | sort avgLatency desc
#
# 7. API GATEWAY: Taxa de erro (4xx e 5xx):
# ------------------------------------------
# fields status
# | stats count() as total,
#         sum(status >= 400 and status < 500) as errors4xx,
#         sum(status >= 500) as errors5xx
# | extend errorRate = (errors4xx + errors5xx) / total * 100
#
# ============================================================================
# CUSTOS DE LOG:
# ============================================================================
#
# CloudWatch Logs Pricing (sa-east-1):
# - Ingest: $0.63 por GB
# - Storage: $0.03 por GB/mês
# - Insights queries: $0.0063 por GB scanned
#
# Estimativa POC (1 dia de retenção):
# - Lambda logs: ~10 MB/dia = $0.006/dia = $0.18/mês
# - API Gateway logs: ~5 MB/dia = $0.003/dia = $0.09/mês
# - TOTAL: ~$0.27/mês (insignificante!)
#
# Retenção maior (30 dias):
# - Lambda: ~300 MB = $0.009/mês storage
# - API Gateway: ~150 MB = $0.0045/mês storage
# - TOTAL: ~$0.014/mês storage (muito barato!)
#
# ============================================================================
# BOAS PRÁTICAS:
# ============================================================================
#
# 1. Use structured logging (JSON) no seu código Go:
#    log.Printf(`{"level":"info","msg":"Request processed","chargeback_id":"%s"}`, id)
#
# 2. Defina níveis de log:
#    - ERROR: Erros que precisam atenção
#    - WARN: Situações anormais mas recuperáveis
#    - INFO: Eventos importantes (default em prod)
#    - DEBUG: Detalhes para troubleshooting (apenas em dev)
#
# 3. Inclua contexto nos logs:
#    - Request ID (para rastrear request end-to-end)
#    - User ID (se autenticado)
#    - Resource IDs (chargeback_id, etc.)
#
# 4. Não logue informações sensíveis:
#    - Senhas, tokens, API keys
#    - Dados de cartão de crédito
#    - PII (personally identifiable information)
#
# 5. Use Log Insights para análise:
#    - Crie queries salvas para problemas comuns
#    - Configure alarmes baseados em queries
#
# ============================================================================
