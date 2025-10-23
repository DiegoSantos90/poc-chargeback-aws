# ============================================================================
# Phase 2: API Gateway + Lambda - Data Sources
# ============================================================================
# Este arquivo importa outputs da Phase 1 que precisamos usar na Phase 2.
# Data sources são "read-only" - eles apenas consultam recursos existentes.

# ----------------------------------------------------------------------------
# VPC Information from Phase 1
# ----------------------------------------------------------------------------

# Busca a VPC criada na Phase 1 pelo nome
# Precisamos da VPC para:
# - Colocar a Lambda dentro da VPC (para acessar DynamoDB via VPC endpoint)
# - Criar security groups
data "aws_vpc" "phase1_vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-vpc-${var.environment}"]
  }
  
  # Este data source falha se a Phase 1 não foi deployada
  # Isso é proposital - não podemos criar Phase 2 sem Phase 1
}

# ----------------------------------------------------------------------------
# Subnets Information from Phase 1
# ----------------------------------------------------------------------------

# Busca as subnets PRIVADAS criadas na Phase 1
# Lambda deve ficar em subnets privadas por segurança
# (subnets privadas têm acesso à internet via NAT Gateway)
data "aws_subnets" "phase1_private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.phase1_vpc.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
  
  # Resultado: lista de IDs das subnets privadas
  # Exemplo: ["subnet-abc123", "subnet-def456"]
}

# ----------------------------------------------------------------------------
# DynamoDB Table from Phase 1
# ----------------------------------------------------------------------------

# Busca a tabela DynamoDB criada na Phase 1
# Precisamos do ARN e nome da tabela para:
# - Dar permissão à Lambda de ler/escrever
# - Configurar variáveis de ambiente da Lambda
data "aws_dynamodb_table" "chargebacks" {
  name = "${var.project_name}-chargebacks-${var.environment}"
  
  # Esta tabela foi criada na Phase 1
  # Contém os registros de chargeback
}

# ----------------------------------------------------------------------------
# S3 Buckets from Phase 1
# ----------------------------------------------------------------------------

# Busca o bucket S3 para arquivos Parquet
# Precisamos do ARN e nome para:
# - Dar permissão à Lambda de ler/escrever
# - Configurar variáveis de ambiente da Lambda
data "aws_s3_bucket" "parquet" {
  bucket = "${var.project_name}-parquet-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  # Bucket para armazenar dados processados em formato Parquet
}

# Busca o bucket S3 para arquivos CSV
data "aws_s3_bucket" "csv" {
  bucket = "${var.project_name}-csv-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  # Bucket para armazenar dados brutos ou exports em CSV
}

# ----------------------------------------------------------------------------
# AWS Account Information
# ----------------------------------------------------------------------------

# Obtém informações da conta AWS atual
# Usamos para:
# - Construir ARNs completos
# - Nomear recursos com account_id (garante unicidade global)
data "aws_caller_identity" "current" {
  # Retorna: account_id, arn, user_id
}

# Obtém informações da região AWS atual
# Usamos para:
# - Construir ARNs específicos da região
# - Validar que estamos na região correta
data "aws_region" "current" {
  # Retorna: name, endpoint
}

# ----------------------------------------------------------------------------
# VPC Endpoints from Phase 1 (Optional but good for validation)
# ----------------------------------------------------------------------------

# Busca o VPC Endpoint do DynamoDB
# Isso valida que o endpoint existe e está disponível
# A Lambda usará este endpoint para acessar DynamoDB sem sair da VPC
data "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = data.aws_vpc.phase1_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.id}.dynamodb"
  
  # Se este data source falhar, significa que o endpoint não foi criado
  # A Lambda ainda funcionará, mas usará a internet para acessar DynamoDB
}

# Busca o VPC Endpoint do S3
# Similar ao DynamoDB, valida que o endpoint está disponível
data "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.phase1_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.id}.s3"
  
  # A Lambda usará este endpoint para acessar S3 sem sair da VPC
}

# ============================================================================
# RESUMO DO QUE ESTE ARQUIVO FAZ:
# ============================================================================
# 
# 1. Importa a VPC da Phase 1 (precisamos do vpc_id)
# 2. Importa as subnets privadas (Lambda ficará nelas)
# 3. Importa a tabela DynamoDB (Lambda vai ler/escrever nela)
# 4. Importa os buckets S3 (Lambda pode precisar ler/escrever neles)
# 5. Obtém informações da conta AWS (para construir ARNs)
# 6. Valida que os VPC Endpoints existem (otimização de rede)
#
# IMPORTANTE:
# - Se qualquer resource da Phase 1 não existir, este arquivo falhará
# - Isso é bom! Evita criar Phase 2 sem Phase 1
# - Todos estes data sources são "read-only" - não criam nada
# ============================================================================
