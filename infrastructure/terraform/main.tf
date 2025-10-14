# Include Phase 1 infrastructure
module "phase1" {
  source = "./phases"
  
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}