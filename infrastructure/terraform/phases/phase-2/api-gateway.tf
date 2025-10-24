# ============================================================================
# Phase 2: API Gateway REST API
# ============================================================================
# API Gateway recebe requests HTTP e invoca a Lambda

# ----------------------------------------------------------------------------
# REST API
# ----------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "API Gateway for Chargeback Management System"
  
  # Endpoint configuration
  endpoint_configuration {
    types = ["REGIONAL"] # Regional é mais rápido e barato para acesso na mesma região
  }
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-api-${var.environment}"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# API Gateway Resource (proxy catch-all)
# ----------------------------------------------------------------------------

# Resource: /{proxy+}
# Captura TODAS as rotas e repassa para a Lambda
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

# EXPLICAÇÃO:
# {proxy+} significa "qualquer path com qualquer profundidade"
# Exemplos que são capturados:
# - /chargebacks
# - /chargebacks/123
# - /chargebacks/123/approve
# - /health
# Todos vão para a mesma Lambda (que roteia internamente)

# ----------------------------------------------------------------------------
# API Gateway Method (ANY method no proxy resource)
# ----------------------------------------------------------------------------

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY" # GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD
  authorization = "NONE" # Sem autenticação na POC (adicionar Cognito/API Key depois)
}

# ----------------------------------------------------------------------------
# API Gateway Integration (conecta método ao Lambda)
# ----------------------------------------------------------------------------

resource "aws_api_gateway_integration" "lambda_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy.http_method
  
  # Lambda proxy integration
  integration_http_method = "POST" # API Gateway sempre usa POST para invocar Lambda
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_alias.live.invoke_arn
  
  # AWS_PROXY significa:
  # - API Gateway passa TODO o evento para Lambda (headers, body, query params, etc.)
  # - Lambda deve retornar resposta no formato esperado
}

# ----------------------------------------------------------------------------
# Root Resource (/) - para health check ou default route
# ----------------------------------------------------------------------------

resource "aws_api_gateway_method" "root" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_rest_api.main.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_rest_api.main.root_resource_id
  http_method = aws_api_gateway_method.root.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_alias.live.invoke_arn
}

# ----------------------------------------------------------------------------
# API Gateway Deployment
# ----------------------------------------------------------------------------

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  # Trigger re-deployment quando houver mudanças
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy.id,
      aws_api_gateway_integration.lambda_proxy.id,
      aws_api_gateway_method.root.id,
      aws_api_gateway_integration.lambda_root.id,
    ]))
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [
    aws_api_gateway_method.proxy,
    aws_api_gateway_integration.lambda_proxy,
    aws_api_gateway_method.root,
    aws_api_gateway_integration.lambda_root
  ]
}

# ----------------------------------------------------------------------------
# API Gateway Stage
# ----------------------------------------------------------------------------

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.api_gateway_stage_name # Default: "dev"
  
  # Access logging (logs de quem acessou a API)
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
  
  # X-Ray tracing (desabilitado na POC para economizar)
  xray_tracing_enabled = false
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-api-stage-${var.environment}"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# API Gateway Method Settings (throttling e caching)
# ----------------------------------------------------------------------------

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*" # Aplica a todos os métodos
  
  settings {
    # Metrics
    metrics_enabled = true
    logging_level   = "INFO" # ERROR, INFO, OFF
    
    # Data trace (logs completos de request/response - usar apenas em dev)
    data_trace_enabled = var.environment == "dev" ? true : false
    
    # Throttling (limites de rate)
    throttling_burst_limit = 100  # Máximo de requests em burst
    throttling_rate_limit  = 50   # Requests por segundo em steady state
    
    # Caching (desabilitado na POC)
    caching_enabled = false
  }
}

# ============================================================================
# RESUMO DA ARQUITETURA:
# ============================================================================
#
# Internet → API Gateway → Lambda (via Alias) → DynamoDB/S3
#
# ROTAS:
# ------
# GET  https://xxxxx.execute-api.sa-east-1.amazonaws.com/dev/
# ANY  https://xxxxx.execute-api.sa-east-1.amazonaws.com/dev/{proxy+}
#
# Exemplos:
# - GET  /dev/chargebacks          → Lambda handler
# - POST /dev/chargebacks          → Lambda handler
# - GET  /dev/chargebacks/123      → Lambda handler
# - PUT  /dev/chargebacks/123      → Lambda handler
# - GET  /dev/health               → Lambda handler
#
# PROXY INTEGRATION:
# ------------------
# - API Gateway passa TUDO para Lambda (headers, body, query params)
# - Lambda decide como rotear internamente
# - Lambda deve retornar response no formato:
#   {
#     "statusCode": 200,
#     "headers": {"Content-Type": "application/json"},
#     "body": "{\"message\":\"Hello\"}"
#   }
#
# THROTTLING:
# -----------
# - Burst: 100 requests simultâneas
# - Rate: 50 requests/segundo em steady state
# - Protege contra ataques DDoS básicos
#
# LOGGING:
# --------
# - Access logs: quem acessou, quando, qual rota
# - Execution logs: detalhes de execução (apenas em dev)
#
# ============================================================================
