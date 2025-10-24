# ============================================================================
# Phase 1: Outputs
# ============================================================================
# Outputs exportam valores para serem usados em outras fases ou módulos

# ----------------------------------------------------------------------------
# VPC Outputs
# ----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# ----------------------------------------------------------------------------
# Subnet Outputs
# ----------------------------------------------------------------------------

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# ----------------------------------------------------------------------------
# Gateway Outputs
# ----------------------------------------------------------------------------

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

# ----------------------------------------------------------------------------
# Security Group Outputs
# ----------------------------------------------------------------------------

output "security_group_dynamodb_id" {
  description = "ID of the DynamoDB security group"
  value       = aws_security_group.dynamodb_access.id
}

# ----------------------------------------------------------------------------
# DynamoDB Outputs
# ----------------------------------------------------------------------------

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.chargebacks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.chargebacks.arn
}

output "dynamodb_stream_arn" {
  description = "ARN of the DynamoDB stream (for event-driven architecture)"
  value       = aws_dynamodb_table.chargebacks.stream_arn
}

# ----------------------------------------------------------------------------
# S3 Outputs
# ----------------------------------------------------------------------------

output "parquet_bucket_name" {
  description = "Name of the S3 bucket for Parquet files"
  value       = aws_s3_bucket.parquet_files.bucket
}

output "parquet_bucket_arn" {
  description = "ARN of the S3 bucket for Parquet files"
  value       = aws_s3_bucket.parquet_files.arn
}

output "csv_bucket_name" {
  description = "Name of the S3 bucket for CSV files"
  value       = aws_s3_bucket.csv_files.bucket
}

output "csv_bucket_arn" {
  description = "ARN of the S3 bucket for CSV files"
  value       = aws_s3_bucket.csv_files.arn
}

# ----------------------------------------------------------------------------
# VPC Endpoint Outputs
# ----------------------------------------------------------------------------

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "dynamodb_vpc_endpoint_id" {
  description = "ID of the DynamoDB VPC Endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}

# ============================================================================
# ESTES OUTPUTS SERÃO USADOS PELA PHASE 2 via data sources
# ============================================================================
