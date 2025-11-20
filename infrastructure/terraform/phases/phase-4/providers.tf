# =============================================================================
# Phase 4 - Required Providers Configuration
# =============================================================================
# This file declares required providers for Phase 4 module.
# Providers are configured in the root module and passed to this child module.
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
}
