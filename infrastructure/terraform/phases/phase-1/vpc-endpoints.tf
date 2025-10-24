# ============================================================================
# Phase 1: VPC Endpoints
# ============================================================================
# VPC Endpoints permitem acesso privado a serviços AWS sem usar internet
# Benefícios:
# - Reduz custos (sem NAT Gateway traffic charges)
# - Melhora performance (tráfego fica na rede AWS)
# - Aumenta segurança (tráfego não sai da VPC)

# ----------------------------------------------------------------------------
# S3 VPC Endpoint (Gateway Endpoint - Free!)
# ----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-s3-endpoint-${var.environment}"
      Environment = var.environment
    }
  )
}

# Associate S3 endpoint with Public Route Table
resource "aws_vpc_endpoint_route_table_association" "s3_public" {
  route_table_id  = aws_route_table.public.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# Associate S3 endpoint with Private Route Tables
resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count           = length(aws_route_table.private)
  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# ----------------------------------------------------------------------------
# DynamoDB VPC Endpoint (Gateway Endpoint - Free!)
# ----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-dynamodb-endpoint-${var.environment}"
      Environment = var.environment
    }
  )
}

# Associate DynamoDB endpoint with Public Route Table
resource "aws_vpc_endpoint_route_table_association" "dynamodb_public" {
  route_table_id  = aws_route_table.public.id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
}

# Associate DynamoDB endpoint with Private Route Tables
resource "aws_vpc_endpoint_route_table_association" "dynamodb_private" {
  count           = length(aws_route_table.private)
  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
}

# ============================================================================
# IMPORTANTE: Gateway Endpoints (S3 e DynamoDB) são GRATUITOS
# Não há custo adicional por usar estes endpoints!
# ============================================================================
