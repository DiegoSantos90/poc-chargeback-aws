# ============================================================================
# Phase 2: API Gateway + Lambda - Variables
# ============================================================================
# Este arquivo define todas as variáveis que a Fase 2 precisa receber
# do módulo principal (main.tf)

# ----------------------------------------------------------------------------
# Project Configuration
# ----------------------------------------------------------------------------

variable "project_name" {
  description = "Nome do projeto (usado como prefixo em todos os recursos)"
  type        = string
  default     = "poc-chargeback"
  
  # Exemplo: Se project_name = "poc-chargeback", os recursos terão nomes como:
  # - poc-chargeback-api-handler-dev
  # - poc-chargeback-api-dev
}

variable "environment" {
  description = "Ambiente de deployment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  # Usado para:
  # - Nomear recursos de forma única por ambiente
  # - Configurar comportamentos específicos (ex: logs mais verbosos em dev)
}

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "sa-east-1"
  
  # Importante: Deve ser a mesma região da Fase 1
  # Todas as integrações (DynamoDB, S3, VPC) estão nesta região
}

# ----------------------------------------------------------------------------
# Lambda Configuration
# ----------------------------------------------------------------------------

variable "lambda_timeout" {
  description = "Timeout máximo de execução da Lambda (em segundos)"
  type        = number
  default     = 25

  # Para POC: 25 segundos é suficiente
  # Para produção: ajustar baseado no tempo real de processamento
  # Máximo permitido: 900 segundos (15 minutos)
}

variable "lambda_memory_size" {
  description = "Memória alocada para a Lambda (em MB)"
  type        = number
  default     = 256

  # Go é muito eficiente: 256MB é mais que suficiente
  # Menos memória = menor custo
  # Mais memória = mais CPU disponível (proporcionalmente)
}

variable "lambda_handler" {
  description = "Nome do handler da função Lambda"
  type        = string
  default     = "bootstrap"
  
  # Para Go compilado:
  # - "bootstrap" é o padrão para Go com custom runtime
  # - "main" se você nomear seu binário como "main"
}

# ----------------------------------------------------------------------------
# CloudWatch Logs Configuration
# ----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 1

  # Para POC: 1 dia é suficiente
  # Para produção: considerar 30, 60 ou 90 dias
  # Mais retenção = maior custo de armazenamento
}

# ----------------------------------------------------------------------------
# API Gateway Configuration
# ----------------------------------------------------------------------------

variable "api_gateway_stage_name" {
  description = "Nome do stage do API Gateway"
  type        = string
  default     = "dev"
  
  # O stage aparece na URL da API:
  # https://api-id.execute-api.sa-east-1.amazonaws.com/dev/
}

# ----------------------------------------------------------------------------
# Tags
# ----------------------------------------------------------------------------

variable "tags" {
  description = "Tags comuns para todos os recursos da Fase 2"
  type        = map(string)
  default = {
    Phase       = "2"
    ManagedBy   = "Terraform"
    Component   = "API"
  }
  
  # Tags ajudam a:
  # - Identificar recursos no AWS Console
  # - Filtrar custos por fase/componente
  # - Organizar recursos
}
