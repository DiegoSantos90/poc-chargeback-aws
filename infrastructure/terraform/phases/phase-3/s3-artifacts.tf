# =============================================================================
# Phase 3 - S3 Artifacts Management
# =============================================================================
# This file manages the automatic upload of the Flink application JAR from
# the local filesystem to S3. This allows us to keep the JAR in the same
# repository and have Terraform manage its deployment.
# =============================================================================

# -----------------------------------------------------------------------------
# Local Variables for Artifact Paths
# -----------------------------------------------------------------------------

locals {
  # Path to the Flink JAR in the repository
  # path.module points to phases/phase-3, so we need to go up 4 levels to reach the repo root
  flink_jar_local_path = "${path.module}/../../../../deployments/flink/chargeback-parquet-writer-1.0.0.jar"
  
  # S3 key where the JAR will be uploaded
  # This matches what kinesis-analytics.tf expects
  flink_jar_s3_key = local.flink_application_jar_key
}

# -----------------------------------------------------------------------------
# S3 Object - Flink Application JAR
# -----------------------------------------------------------------------------
# Automatically uploads the Flink JAR from the local filesystem to S3
# Terraform will only upload if:
# 1. The file doesn't exist in S3 yet, OR
# 2. The local file has changed (based on MD5 hash)

resource "aws_s3_object" "flink_application_jar" {
  bucket = var.parquet_bucket_name
  key    = local.flink_jar_s3_key
  source = local.flink_jar_local_path
  
  # ETag for version control - Terraform will update if the file changes
  etag = filemd5(local.flink_jar_local_path)
  
  # Metadata for tracking
  metadata = {
    "uploaded-by"        = "terraform"
    "application"        = var.flink_application_name
    "runtime-version"    = var.flink_runtime_environment
    "terraform-phase"    = "phase-3"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name        = "Flink Application JAR - ${var.flink_application_name}"
      Purpose     = "Flink Application Code"
      Phase       = "Phase 3"
      Managed-By  = "Terraform"
    }
  )
  
  # Only create this resource if the local JAR file exists
  lifecycle {
    precondition {
      condition     = fileexists(local.flink_jar_local_path)
      error_message = "Flink JAR file not found at ${local.flink_jar_local_path}. Please build the Flink application first."
    }
  }
}

# -----------------------------------------------------------------------------
# Data Source - Flink Application JAR (for validation)
# -----------------------------------------------------------------------------
# This data source validates that the JAR was successfully uploaded
# and provides its metadata to other resources

data "aws_s3_object" "flink_application_jar" {
  bucket = var.parquet_bucket_name
  key    = local.flink_jar_s3_key
  
  # Wait for the JAR to be uploaded first
  depends_on = [aws_s3_object.flink_application_jar]
}

# -----------------------------------------------------------------------------
# Outputs for Debugging
# -----------------------------------------------------------------------------

output "flink_jar_upload_status" {
  description = "Status of the Flink JAR upload to S3"
  value = {
    local_path    = local.flink_jar_local_path
    s3_bucket     = var.parquet_bucket_name
    s3_key        = local.flink_jar_s3_key
    s3_uri        = "s3://${var.parquet_bucket_name}/${local.flink_jar_s3_key}"
    file_size_mb  = data.aws_s3_object.flink_application_jar.content_length / 1024 / 1024
    etag          = data.aws_s3_object.flink_application_jar.etag
    last_modified = data.aws_s3_object.flink_application_jar.last_modified
  }
}
