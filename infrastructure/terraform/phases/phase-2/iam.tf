# ============================================================================
# Phase 2: IAM Roles and Policies for Lambda
# ============================================================================
# Este arquivo cria a IAM Role e políticas necessárias para a Lambda funcionar

# ----------------------------------------------------------------------------
# Lambda Execution Role
# ----------------------------------------------------------------------------

resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-${var.environment}"
  
  # Trust Policy: permite que o serviço Lambda assuma esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-lambda-execution-role-${var.environment}"
      Environment = var.environment
    }
  )
}

# ----------------------------------------------------------------------------
# Policy: VPC Access (para Lambda rodar dentro da VPC)
# ----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Esta policy managed da AWS permite:
# - Criar/gerenciar Elastic Network Interfaces (ENI)
# - Descrever subnets e security groups
# - Necessária para Lambda rodar dentro da VPC

# ----------------------------------------------------------------------------
# Policy: CloudWatch Logs (para logging)
# ----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Esta policy managed da AWS permite:
# - Criar log groups
# - Criar log streams
# - Escrever logs no CloudWatch

# ----------------------------------------------------------------------------
# Custom Policy: DynamoDB Access
# ----------------------------------------------------------------------------

resource "aws_iam_policy" "dynamodb_access" {
  name        = "${var.project_name}-lambda-dynamodb-${var.environment}"
  description = "Allow Lambda to access DynamoDB table"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          data.aws_dynamodb_table.chargebacks.arn,
          "${data.aws_dynamodb_table.chargebacks.arn}/index/*" # GSI access
        ]
      }
    ]
  })
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-dynamodb-policy-${var.environment}"
      Environment = var.environment
    }
  )
}

# Attach custom DynamoDB policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# ----------------------------------------------------------------------------
# Custom Policy: S3 Access (para ler/escrever arquivos)
# ----------------------------------------------------------------------------

resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-lambda-s3-${var.environment}"
  description = "Allow Lambda to access S3 buckets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          data.aws_s3_bucket.parquet.arn,
          "${data.aws_s3_bucket.parquet.arn}/*",
          data.aws_s3_bucket.csv.arn,
          "${data.aws_s3_bucket.csv.arn}/*"
        ]
      }
    ]
  })
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-s3-policy-${var.environment}"
      Environment = var.environment
    }
  )
}

# Attach custom S3 policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# ============================================================================
# RESUMO DAS PERMISSÕES:
# ============================================================================
#
# 1. AWSLambdaVPCAccessExecutionRole (AWS Managed)
#    - Gerenciar ENIs para rodar dentro da VPC
#
# 2. AWSLambdaBasicExecutionRole (AWS Managed)
#    - Criar e escrever logs no CloudWatch
#
# 3. DynamoDB Access (Custom Policy)
#    - Full CRUD na tabela chargebacks
#    - Query/Scan com suporte a GSI
#
# 4. S3 Access (Custom Policy)
#    - Read/Write nos buckets Parquet e CSV
#    - List buckets
#
# ============================================================================
# PRINCÍPIO DO MENOR PRIVILÉGIO:
# ============================================================================
# - Permissões limitadas apenas aos recursos específicos (ARNs)
# - Sem wildcard (*) desnecessário
# - Apenas ações necessárias para a aplicação funcionar
# ============================================================================
