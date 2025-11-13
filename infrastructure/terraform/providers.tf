# =============================================================================
# Root Provider Configuration
# =============================================================================
# This file configures providers for the root module that orchestrates all phases
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
  
  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "poc-chargeback/terraform.tfstate"
  #   region = "sa-east-1"
  # }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project   = var.project_name
      Environment = var.environment
      ManagedBy = "Terraform"
    }
  }
}

# Kafka Provider Configuration
# Note: This provider is only used when Phase 3 MSK cluster is deployed
# The bootstrap_servers will be populated after Phase 3 is created
provider "kafka" {
  # Use Phase 3 MSK bootstrap servers (only works after Phase 3 is deployed)
  bootstrap_servers = try(split(",", module.phase3.msk_bootstrap_brokers), ["localhost:9092"])
  
  # MSK Serverless with IAM authentication
  tls_enabled    = true
  sasl_mechanism = "aws-iam"  # Valid values: scram-sha256, scram-sha512, aws-iam, oauthbearer, plain
  
  # Skip TLS verification for initial deployment (before MSK exists)
  skip_tls_verify = false
}