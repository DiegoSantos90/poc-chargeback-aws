# ============================================================================
# Phase 1: Foundation - Variables
# ============================================================================
# Este arquivo define todas as variáveis configuráveis da Phase 1

# ----------------------------------------------------------------------------
# Project Configuration
# ----------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project (used as prefix for all resources)"
  type        = string
  default     = "poc-chargeback"
  
  # Used to create unique resource names like:
  # - poc-chargeback-vpc
  # - poc-chargeback-parquet-files-dev
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  # Used for:
  # - Resource naming
  # - Environment-specific configurations (e.g., force_destroy on S3)
  # - Tagging
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
  
  # Important: All Phase 1 and Phase 2 resources must be in the same region
}

# ----------------------------------------------------------------------------
# VPC Configuration
# ----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  # This provides 65,536 IP addresses
  # Public subnets: 10.0.0.0/24, 10.0.1.0/24, etc.
  # Private subnets: 10.0.10.0/24, 10.0.11.0/24, etc.
}

variable "availability_zones" {
  description = "Availability zones for high availability"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  
  # High availability: Resources distributed across multiple AZs
  # Each AZ gets:
  # - 1 public subnet
  # - 1 private subnet
  # - 1 NAT Gateway
}

# ----------------------------------------------------------------------------
# Tags
# ----------------------------------------------------------------------------

variable "tags" {
  description = "Common tags for all Phase 1 resources"
  type        = map(string)
  default = {
    Phase       = "1"
    ManagedBy   = "Terraform"
    Component   = "Foundation"
  }
  
  # These tags help with:
  # - Resource organization in AWS Console
  # - Cost allocation and tracking
  # - Automation and filtering
}
