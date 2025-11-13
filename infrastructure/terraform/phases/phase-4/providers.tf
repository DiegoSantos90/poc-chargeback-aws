# =============================================================================
# Phase 4 - Provider Configuration
# =============================================================================
# This file configures the required Terraform providers for Phase 4:
# - AWS provider for Glue, S3, EventBridge, CloudWatch
# - Kafka provider for managing MSK topics
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kafka = {
      source  = "Mongey/kafka"
      version = "~> 0.7.0"
    }
  }

  # Uncomment to configure remote state backend
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "poc-chargeback/phase-4/terraform.tfstate"
  #   region = "sa-east-1"
  # }
}

# AWS Provider Configuration
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

# Kafka Provider Configuration (for MSK topic management)
# Only configured when Kafka is enabled and bootstrap servers are provided
provider "kafka" {
  bootstrap_servers = var.msk_bootstrap_brokers != "" ? split(",", var.msk_bootstrap_brokers) : ["localhost:9092"]
  
  # MSK Serverless with IAM authentication
  tls_enabled    = true
  sasl_mechanism = "aws"
  
  # Skip TLS verification for local development (remove in production)
  skip_tls_verify = false
}
