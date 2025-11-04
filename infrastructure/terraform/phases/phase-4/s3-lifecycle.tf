# =============================================================================
# Phase 4 - S3 Lifecycle Policies
# =============================================================================
# This file creates S3 lifecycle policies to manage data retention for:
# 1. Landing zone files (after consolidation)
# 2. Consolidated files (long-term archival)
# 3. Glue temporary files (automatic cleanup)
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Lifecycle Rule - Landing Zone Cleanup
# -----------------------------------------------------------------------------
# Deletes landing zone files after consolidation (if enabled)
# This saves storage costs by removing small files once they're consolidated

resource "aws_s3_bucket_lifecycle_configuration" "landing_zone_cleanup" {
  count  = var.landing_zone_retention_enabled ? 1 : 0
  bucket = var.parquet_bucket_name
  
  rule {
    id     = "landing-zone-cleanup"
    status = "Enabled"
    
    # Apply to landing zone prefix only
    filter {
      prefix = "${var.s3_landing_prefix}/"
    }
    
    # Delete files after N days
    expiration {
      days = var.landing_zone_retention_days
    }
    
    # Also delete old versions (if versioning is enabled)
    noncurrent_version_expiration {
      noncurrent_days = var.landing_zone_retention_days
    }
    
    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Lifecycle Rule - Consolidated Data Archival
# -----------------------------------------------------------------------------
# Transitions consolidated data to cheaper storage classes over time

resource "aws_s3_bucket_lifecycle_configuration" "consolidated_archival" {
  count  = var.consolidated_data_retention_enabled ? 1 : 0
  bucket = var.parquet_bucket_name
  
  rule {
    id     = "consolidated-data-archival"
    status = "Enabled"
    
    # Apply to consolidated prefix only
    filter {
      prefix = "${var.s3_consolidated_prefix}/"
    }
    
    # Transition to Standard-IA after 30 days (for infrequent access)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    # Transition to Glacier after 90 days (for long-term archival)
    transition {
      days          = var.consolidated_data_retention_days
      storage_class = "GLACIER"
    }
    
    # Transition to Deep Archive after 1 year (lowest cost)
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
    
    # Noncurrent versions (if versioning enabled)
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
    
    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Lifecycle Rule - Glue Temporary Files Cleanup
# -----------------------------------------------------------------------------
# Automatically clean up Glue temporary files (always enabled)

resource "aws_s3_bucket_lifecycle_configuration" "glue_temp_cleanup" {
  bucket = var.parquet_bucket_name
  
  rule {
    id     = "glue-temp-cleanup"
    status = "Enabled"
    
    # Apply to Glue temp prefix
    filter {
      prefix = "${var.s3_glue_temp_prefix}/"
    }
    
    # Delete temp files after 1 day
    expiration {
      days = 1
    }
    
    # Abort incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
  
  rule {
    id     = "glue-spark-logs-cleanup"
    status = "Enabled"
    
    # Apply to Spark logs prefix
    filter {
      prefix = "${var.s3_glue_spark_logs_prefix}/"
    }
    
    # Keep Spark logs for 7 days
    expiration {
      days = 7
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Intelligent-Tiering Configuration (Optional)
# -----------------------------------------------------------------------------
# Alternative to lifecycle rules: let S3 automatically move data between tiers
# Uncomment if you prefer automatic cost optimization

# resource "aws_s3_bucket_intelligent_tiering_configuration" "consolidated_data" {
#   bucket = var.parquet_bucket_name
#   name   = "consolidated-data-tiering"
#   status = "Enabled"
#   
#   filter {
#     prefix = "${var.s3_consolidated_prefix}/"
#   }
#   
#   # Archive after 90 days of no access
#   tiering {
#     access_tier = "ARCHIVE_ACCESS"
#     days        = 90
#   }
#   
#   # Deep archive after 180 days of no access
#   tiering {
#     access_tier = "DEEP_ARCHIVE_ACCESS"
#     days        = 180
#   }
# }

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "lifecycle_rules" {
  description = "Summary of S3 lifecycle rules"
  value = {
    landing_zone_cleanup = {
      enabled        = var.landing_zone_retention_enabled
      retention_days = var.landing_zone_retention_days
    }
    consolidated_archival = {
      enabled        = var.consolidated_data_retention_enabled
      retention_days = var.consolidated_data_retention_days
    }
    glue_temp_cleanup = {
      enabled = true
      message = "Temporary files deleted after 1 day"
    }
  }
}
