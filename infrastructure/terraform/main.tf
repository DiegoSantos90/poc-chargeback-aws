# Include Phase 1 infrastructure
module "phase1" {
  source = "./phases/phase-1"
  
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# Include Phase 2 infrastructure
module "phase2" {
  source = "./phases/phase-2"
  
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  
  # Lambda configuration
  lambda_timeout     = 25
  lambda_memory_size = 256
  lambda_handler     = "bootstrap"
  
  # CloudWatch configuration
  log_retention_days = 1
  
  # API Gateway configuration
  api_gateway_stage_name = "dev"
  
  # Tags
  tags = {
    Phase       = "2"
    ManagedBy   = "Terraform"
    Component   = "API"
  }
  
  # Depende da Phase 1 estar completa
  depends_on = [module.phase1]
}
