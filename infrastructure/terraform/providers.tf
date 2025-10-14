# Provider configuration
provider "aws" {
  region = var.aws_region
}

# Configure Terraform state backend (optional but recommended)
terraform {
  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "poc-chargeback/phase-1/terraform.tfstate"
  #   region = "us-east-1"
  # }
}