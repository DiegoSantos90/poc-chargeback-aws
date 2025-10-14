# Terraform configuration for outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.phase1.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.phase1.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.phase1.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"  
  value       = module.phase1.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.phase1.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.phase1.nat_gateway_ids
}

output "security_group_dynamodb_id" {
  description = "ID of the DynamoDB security group"
  value       = module.phase1.security_group_dynamodb_id
}

# Database and Storage Outputs
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for chargebacks"
  value       = module.phase1.dynamodb_table_name
}

output "dynamodb_stream_arn" {
  description = "ARN of the DynamoDB stream (needed for future phases)"
  value       = module.phase1.dynamodb_stream_arn
}

output "parquet_bucket_name" {
  description = "Name of the S3 bucket for storing parquet files"
  value       = module.phase1.parquet_bucket_name
}

output "csv_bucket_name" {
  description = "Name of the S3 bucket for storing CSV files"
  value       = module.phase1.csv_bucket_name
}

# General Outputs
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}