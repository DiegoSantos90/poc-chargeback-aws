# Phase 1: Foundation - Core Storage Infrastructure
# DynamoDB, S3, IAM Roles

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "poc-chargeback"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    Phase       = "1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    Phase       = "1"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Public"
    Phase       = "1"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Private"
    Phase       = "1"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip-${count.index + 1}"
    Environment = var.environment
    Phase       = "1"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.project_name}-nat-gateway-${count.index + 1}"
    Environment = var.environment
    Phase       = "1"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
    Phase       = "1"
  }
}

# Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-private-rt-${count.index + 1}"
    Environment = var.environment
    Phase       = "1"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Tables
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Endpoints for S3 (reduces costs and improves performance)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  tags = {
    Name        = "${var.project_name}-s3-endpoint"
    Environment = var.environment
    Phase       = "1"
  }
}

# VPC Endpoint Route Table Association
resource "aws_vpc_endpoint_route_table_association" "s3_public" {
  route_table_id  = aws_route_table.public.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count           = length(aws_route_table.private)
  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# VPC Endpoint for DynamoDB
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.dynamodb"
  
  tags = {
    Name        = "${var.project_name}-dynamodb-endpoint"
    Environment = var.environment
    Phase       = "1"
  }
}

# VPC Endpoint Route Table Association for DynamoDB
resource "aws_vpc_endpoint_route_table_association" "dynamodb_public" {
  route_table_id  = aws_route_table.public.id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb_private" {
  count           = length(aws_route_table.private)
  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
}

# Security Group for DynamoDB access
resource "aws_security_group" "dynamodb_access" {
  name_prefix = "${var.project_name}-dynamodb-access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-dynamodb-sg"
    Environment = var.environment
    Phase       = "1"
  }
}

# DynamoDB Table for Chargebacks
resource "aws_dynamodb_table" "chargebacks" {
  name           = "chargebacks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "chargeback_id"
  
  attribute {
    name = "chargeback_id"
    type = "S"
  }
  
  attribute {
    name = "status"
    type = "S"
  }
  
  # Enable DynamoDB Streams
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  
  # Global Secondary Index for status queries
  global_secondary_index {
    name               = "status-index"
    hash_key           = "status"
    projection_type    = "ALL"
  }
  
  tags = {
    Name        = "Chargebacks Table"
    Environment = var.environment
    Phase       = "1"
  }
}

# S3 Bucket for Parquet Files
resource "aws_s3_bucket" "parquet_files" {
  bucket = "${var.project_name}-parquet-files-${var.environment}"
  
  # Enable force_destroy for development environments
  # WARNING: This will delete all objects when destroying the bucket
  force_destroy = var.environment == "dev" ? true : false
  
  tags = {
    Name        = "Parquet Files Bucket"
    Environment = var.environment
    Phase       = "1"
  }
}

# S3 Bucket for CSV Files
resource "aws_s3_bucket" "csv_files" {
  bucket = "${var.project_name}-csv-files-${var.environment}"
  
  # Enable force_destroy for development environments  
  # WARNING: This will delete all objects when destroying the bucket
  force_destroy = var.environment == "dev" ? true : false
  
  tags = {
    Name        = "CSV Files Bucket"
    Environment = var.environment
    Phase       = "1"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "parquet_versioning" {
  bucket = aws_s3_bucket.parquet_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "csv_versioning" {
  bucket = aws_s3_bucket.csv_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Basic IAM policies and roles will be added in later phases when needed

# Outputs for validation and future phases
output "vpc_id" {
  description = "ID of the VPC"
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value = aws_nat_gateway.main[*].id
}

output "security_group_dynamodb_id" {
  description = "ID of the DynamoDB security group"
  value = aws_security_group.dynamodb_access.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value = aws_dynamodb_table.chargebacks.name
}

output "dynamodb_stream_arn" {
  description = "ARN of the DynamoDB stream (for future phases)"
  value = aws_dynamodb_table.chargebacks.stream_arn
}

output "parquet_bucket_name" {
  description = "Name of the S3 bucket for parquet files"
  value = aws_s3_bucket.parquet_files.bucket
}

output "csv_bucket_name" {
  description = "Name of the S3 bucket for CSV files" 
  value = aws_s3_bucket.csv_files.bucket
}