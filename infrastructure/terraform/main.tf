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

# Include Phase 3 infrastructure
module "phase3" {
  source = "./phases/phase-3"
  
  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  
  # Import Phase 1 resources (VPC, Networking, DynamoDB, S3)
  vpc_id                      = module.phase1.vpc_id
  private_subnet_ids          = module.phase1.private_subnet_ids
  security_group_dynamodb_id  = module.phase1.security_group_dynamodb_id
  dynamodb_table_name         = module.phase1.dynamodb_table_name
  dynamodb_stream_arn         = module.phase1.dynamodb_stream_arn
  dynamodb_table_arn          = module.phase1.dynamodb_table_arn
  parquet_bucket_name         = module.phase1.parquet_bucket_name
  parquet_bucket_arn          = module.phase1.parquet_bucket_arn
  csv_bucket_name             = module.phase1.csv_bucket_name
  csv_bucket_arn              = module.phase1.csv_bucket_arn
  s3_vpc_endpoint_id          = module.phase1.s3_vpc_endpoint_id
  dynamodb_vpc_endpoint_id    = module.phase1.dynamodb_vpc_endpoint_id
  
  # MSK configuration
  msk_cluster_name            = "chargebacks-cluster"
  kafka_topic_name            = "chargebacks"
  kafka_topic_partitions      = 3
  
  # Lambda configuration
  lambda_runtime              = "python3.11"
  lambda_memory_size          = 512
  lambda_timeout              = 60
  lambda_batch_size           = 100
  
  # Flink configuration
  flink_runtime_environment   = "FLINK-1_15"
  flink_parallelism           = 1
  flink_checkpointing_enabled = true
  flink_checkpoint_interval   = 60000
  
  # CloudWatch configuration
  log_retention_days          = 1
  enable_msk_monitoring       = true
  enable_flink_metrics        = true
  
  # Tags
  tags = {
    Phase       = "3"
    ManagedBy   = "Terraform"
    Component   = "Streaming"
  }
  
  # Depends on Phase 1 (needs VPC, DynamoDB Stream, S3)
  depends_on = [module.phase1]
}

# Include Phase 4 infrastructure
module "phase4" {
  source = "./phases/phase-4"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.aws_region
  
  # Import Phase 1 resources (S3 buckets)
  parquet_bucket_name = module.phase1.parquet_bucket_name
  parquet_bucket_arn  = module.phase1.parquet_bucket_arn
  
  # Import Phase 3 resources (MSK cluster for Kafka notifications)
  msk_bootstrap_brokers  = module.phase3.msk_bootstrap_brokers
  msk_cluster_arn        = module.phase3.msk_cluster_arn
  msk_security_group_id  = module.phase3.msk_security_group_id
  vpc_id                 = module.phase1.vpc_id
  private_subnet_ids     = module.phase1.private_subnet_ids
  
  # Glue configuration
  glue_database_name         = "chargeback_data"
  glue_crawler_name          = "chargebacks-landing-crawler"
  glue_job_name              = "chargebacks-consolidation"
  glue_job_worker_type       = "G.1X"
  glue_job_number_of_workers = 2
  glue_job_timeout           = 60
  
  # Data consolidation configuration
  consolidation_executions_per_day = 4
  consolidation_output_files       = 1
  output_format                    = "csv"
  
  # Kafka integration
  enable_kafka_notifications           = true
  kafka_consolidation_topic            = "chargeback-consolidation-events"
  kafka_consolidation_topic_partitions = 3
  kafka_consolidation_topic_replication = 3
  
  # EventBridge scheduler
  enable_scheduler   = true
  scheduler_timezone = "America/Sao_Paulo"
  
  # CloudWatch monitoring
  enable_cloudwatch_alarms = true
  alarm_email_endpoints    = []
  
  # Tags
  tags = {
    Phase     = "4"
    ManagedBy = "Terraform"
    Component = "DataConsolidation"
  }
  
  # Depends on Phase 1 (S3) and Phase 3 (MSK)
  depends_on = [module.phase1, module.phase3]
}
