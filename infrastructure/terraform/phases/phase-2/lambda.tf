# ============================================================================
# Phase 2: Lambda Function
# ============================================================================
# Este arquivo cria a função Lambda que executará a API Go

# ----------------------------------------------------------------------------
# Lambda Function
# ----------------------------------------------------------------------------

resource "aws_lambda_function" "api_handler" {
  function_name = "${var.project_name}-api-handler-${var.environment}"
  description   = "API handler for chargeback management"
  
  # Runtime and Handler
  runtime = "provided.al2023" # Go custom runtime on Amazon Linux 2023
  handler = var.lambda_handler # Default: "bootstrap"
  
  # Code deployment
  filename         = "${path.root}/../../deployments/lambda/function.zip"
  source_code_hash = filebase64sha256("${path.root}/../../deployments/lambda/function.zip")
  
  # Execution role (criada no iam.tf)
  role = aws_iam_role.lambda_execution.arn
  
  # Resource allocation
  memory_size = var.lambda_memory_size # Default: 256 MB
  timeout     = var.lambda_timeout     # Default: 25 seconds
  
  # ----------------------------------------------------------------------------
  # VPC Configuration (para acesso privado a DynamoDB/S3)
  # ----------------------------------------------------------------------------
  vpc_config {
    subnet_ids         = data.aws_subnets.phase1_private_subnets.ids
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  # ----------------------------------------------------------------------------
  # Environment Variables (configuração da aplicação)
  # ----------------------------------------------------------------------------
  environment {
    variables = {
      # AWS Configuration
      AWS_REGION = var.aws_region
      
      # DynamoDB Configuration
      DYNAMODB_TABLE_NAME = data.aws_dynamodb_table.chargebacks.name
      DYNAMODB_ENDPOINT   = "https://dynamodb.${var.aws_region}.amazonaws.com"
      
      # S3 Configuration
      S3_PARQUET_BUCKET = data.aws_s3_bucket.parquet.bucket
      S3_CSV_BUCKET     = data.aws_s3_bucket.csv.bucket
      S3_ENDPOINT       = "https://s3.${var.aws_region}.amazonaws.com"
      
      # Application Configuration
      ENVIRONMENT = var.environment
      LOG_LEVEL   = var.environment == "dev" ? "DEBUG" : "INFO"
      
      # Feature Flags (pode adicionar mais conforme necessário)
      ENABLE_METRICS = "true"
      ENABLE_TRACING = "false" # X-Ray desabilitado na POC
    }
  }
  
  # ----------------------------------------------------------------------------
  # Reserved Concurrent Executions (limita execuções simultâneas)
  # ----------------------------------------------------------------------------
  # Para POC: não definimos limite (usa account default)
  # Para produção: definir baseado em capacidade esperada
  # reserved_concurrent_executions = 10
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-lambda-${var.environment}"
      Environment = var.environment
    }
  )
  
  # Depende dos recursos da Phase 1
  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_dynamodb,
    aws_iam_role_policy_attachment.lambda_s3
  ]
  
  # ----------------------------------------------------------------------------
  # Publish Version (cria uma nova versão a cada deploy)
  # ----------------------------------------------------------------------------
  publish = true
  
  # Quando publish = true:
  # - Cada deploy cria uma versão imutável (v1, v2, v3, etc.)
  # - Versões são imutáveis (não podem ser modificadas)
  # - Facilita rollback para versões anteriores
}

# ----------------------------------------------------------------------------
# Lambda Version (captura a versão publicada)
# ----------------------------------------------------------------------------

# Esta data source captura a versão LATEST (não qualificada)
# Útil para referência, mas não é usada para invocação
data "aws_lambda_function" "current" {
  function_name = aws_lambda_function.api_handler.function_name
  
  depends_on = [aws_lambda_function.api_handler]
}

# ----------------------------------------------------------------------------
# Lambda Alias (pointer para uma versão específica)
# ----------------------------------------------------------------------------

resource "aws_lambda_alias" "live" {
  name             = var.environment # "dev", "staging", "prod"
  description      = "Alias for ${var.environment} environment"
  function_name    = aws_lambda_function.api_handler.function_name
  function_version = aws_lambda_function.api_handler.version
  
  # Lifecycle para atualização suave
  lifecycle {
    ignore_changes = [function_version]
  }
}

# EXPLICAÇÃO DO ALIAS:
# --------------------
# - Alias é um pointer para uma versão específica da Lambda
# - API Gateway aponta para o ALIAS (não para $LATEST ou versão específica)
# - Para fazer rollback: aws lambda update-alias --function-version <old_version>
# - Permite Blue/Green deployment com weight routing

# ----------------------------------------------------------------------------
# Lambda Permission (permite API Gateway invocar a Lambda via Alias)
# ----------------------------------------------------------------------------

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  qualifier     = aws_lambda_alias.live.name # Invoca via alias
  
  # Permite que qualquer rota do API Gateway invoque esta Lambda via alias
  source_arn = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ============================================================================
# DETALHES IMPORTANTES:
# ============================================================================
#
# RUNTIME: provided.al2023
# ------------------------
# - Go usa custom runtime (Go não tem runtime managed pela AWS)
# - "provided.al2023" é Amazon Linux 2023 (mais recente e otimizado)
# - Binary Go compilado deve se chamar "bootstrap" (ou usar handler customizado)
#
# HANDLER: bootstrap
# ------------------
# - Nome padrão para Go Lambda
# - Seu código Go compilado gera um executável chamado "bootstrap"
#
# CODE DEPLOYMENT:
# ----------------
# - Espera zip em: deployments/lambda/function.zip
# - source_code_hash: detecta mudanças no código para re-deploy
# - Estrutura do zip:
#   function.zip
#   └── bootstrap (executável Go compilado)
#
# VPC CONFIGURATION:
# ------------------
# - Lambda roda em subnets PRIVADAS (segurança)
# - Usa security group criado em security-groups.tf
# - Cold start +300ms devido a ENI creation
#
# ENVIRONMENT VARIABLES:
# ----------------------
# - Seu código Go pode ler estas variáveis com os.Getenv()
# - Facilita configuração sem recompilar
# - LOG_LEVEL muda conforme ambiente (DEBUG em dev, INFO em prod)
#
# ============================================================================
# VERSIONAMENTO E ROLLBACK:
# ============================================================================
#
# PUBLISH = TRUE:
# ---------------
# - Cada deploy cria uma versão imutável (v1, v2, v3, etc.)
# - Versões antigas permanecem disponíveis para rollback
# - Terraform cria automaticamente nova versão a cada mudança
#
# ALIAS:
# ------
# - Alias aponta para uma versão específica da Lambda
# - API Gateway invoca a Lambda VIA ALIAS (não $LATEST)
# - Nome do alias = environment (dev, staging, prod)
#
# COMO FAZER ROLLBACK:
# --------------------
# 
# 1. Listar versões disponíveis:
#    aws lambda list-versions-by-function \
#      --function-name poc-chargeback-api-handler-dev \
#      --region sa-east-1
#
# 2. Ver qual versão o alias aponta atualmente:
#    aws lambda get-alias \
#      --function-name poc-chargeback-api-handler-dev \
#      --name dev \
#      --region sa-east-1
#
# 3. Fazer rollback para versão anterior (exemplo: v5):
#    aws lambda update-alias \
#      --function-name poc-chargeback-api-handler-dev \
#      --name dev \
#      --function-version 5 \
#      --region sa-east-1
#
# 4. IMEDIATO! Não precisa re-deploy do API Gateway
#    API Gateway já está apontando para o alias
#    Rollback é instantâneo (< 1 segundo)
#
# BLUE/GREEN DEPLOYMENT (Avançado):
# ----------------------------------
# - Dividir tráfego entre versões (ex: 90% v6, 10% v7)
#    aws lambda update-alias \
#      --function-name poc-chargeback-api-handler-dev \
#      --name dev \
#      --function-version 7 \
#      --routing-config AdditionalVersionWeights={"6"=0.9}
#
# - Útil para testar nova versão com tráfego real gradualmente
# - Canary deployment: começa com 10%, aumenta gradualmente
#
# ============================================================================
# COMO COMPILAR GO PARA LAMBDA:
# ============================================================================
# 
# GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o bootstrap main.go
# zip function.zip bootstrap
# mv function.zip deployments/lambda/
#
# ============================================================================
