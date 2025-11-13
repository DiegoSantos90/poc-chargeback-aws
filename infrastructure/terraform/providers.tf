# Provider configuration
provider "aws" {
  region = var.aws_region
}

# Configure Terraform state backend (optional but recommended)
terraform {
  required_providers {
    kafka = {
      source = "Mongey/kafka"
      version = "~> 0.4.0" # Use an appropriate version
    }
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.17.0" # Use an appropriate version
    }
  }
  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "poc-chargeback/phase-1/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "kafka" {
  bootstrap_servers = split(",", module.phase3.msk_bootstrap_brokers)
  tls_enabled       = true
  sasl_mechanism    = "aws-iam"
  sasl_aws_region   = var.aws_region
}