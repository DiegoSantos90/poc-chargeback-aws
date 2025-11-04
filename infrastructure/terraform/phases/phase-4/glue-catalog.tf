# =============================================================================
# Phase 4 - AWS Glue Data Catalog
# =============================================================================
# This file creates the Glue database and tables for chargeback data.
# The catalog serves as a centralized metadata store for both landing zone
# (raw 1:1 files) and consolidated (optimized) data.
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Glue Database
# -----------------------------------------------------------------------------

resource "aws_glue_catalog_database" "chargeback_data" {
  name        = local.glue_database_name
  description = var.glue_database_description
  
  # Location hint for S3 (optional, crawler will discover actual locations)
  location_uri = "s3://${var.parquet_bucket_name}/"
  
  tags = merge(
    local.common_tags,
    {
      Name = local.glue_database_name
    }
  )
}

# -----------------------------------------------------------------------------
# AWS Glue Table - Consolidated Data (manually defined for better control)
# -----------------------------------------------------------------------------
# The landing table will be created automatically by the Crawler.
# We manually define the consolidated table for explicit schema control.

resource "aws_glue_catalog_table" "chargebacks_consolidated" {
  name          = local.consolidated_table_name
  database_name = aws_glue_catalog_database.chargeback_data.name
  description   = "Consolidated chargeback data optimized for analytics"
  
  table_type = "EXTERNAL_TABLE"
  
  # Partition keys (date-based partitioning)
  partition_keys {
    name = "year"
    type = "string"
  }
  
  partition_keys {
    name = "month"
    type = "string"
  }
  
  partition_keys {
    name = "day"
    type = "string"
  }
  
  # Storage descriptor
  storage_descriptor {
    location      = local.consolidated_s3_path
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    
    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      
      parameters = {
        "serialization.format" = "1"
      }
    }
    
    # Schema definition (based on DynamoDB chargeback structure)
    columns {
      name = "chargeback_id"
      type = "string"
      comment = "Unique chargeback identifier"
    }
    
    columns {
      name = "status"
      type = "string"
      comment = "Chargeback status: pending, approved, rejected, processing"
    }
    
    columns {
      name = "merchant_id"
      type = "string"
      comment = "Merchant identifier"
    }
    
    columns {
      name = "amount"
      type = "double"
      comment = "Chargeback amount"
    }
    
    columns {
      name = "currency"
      type = "string"
      comment = "Currency code (USD, BRL, EUR, etc.)"
    }
    
    columns {
      name = "created_at"
      type = "timestamp"
      comment = "Chargeback creation timestamp"
    }
    
    columns {
      name = "updated_at"
      type = "timestamp"
      comment = "Last update timestamp"
    }
    
    columns {
      name = "reason"
      type = "string"
      comment = "Chargeback reason/description"
    }
    
    columns {
      name = "metadata"
      type = "struct<transaction_id:string,customer_email:string>"
      comment = "Additional metadata (nested structure)"
    }
    
    columns {
      name = "event_type"
      type = "string"
      comment = "DynamoDB Stream event type: INSERT, MODIFY, REMOVE"
    }
    
    columns {
      name = "event_timestamp"
      type = "timestamp"
      comment = "DynamoDB Stream event timestamp"
    }
    
    # Compression and format
    compressed = true
    
    parameters = {
      "projection.enabled"          = "true"
      "projection.year.type"        = "integer"
      "projection.year.range"       = "2024,2030"
      "projection.month.type"       = "integer"
      "projection.month.range"      = "1,12"
      "projection.month.digits"     = "2"
      "projection.day.type"         = "integer"
      "projection.day.range"        = "1,31"
      "projection.day.digits"       = "2"
      "storage.location.template"   = "${local.consolidated_s3_path}/year=$${year}/month=$${month}/day=$${day}"
      "classification"              = "parquet"
      "compressionType"             = var.parquet_compression_codec
      "typeOfData"                  = "file"
    }
  }
  
  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Allow crawler to update schema if needed
      storage_descriptor[0].columns
    ]
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "glue_database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.chargeback_data.name
}

output "glue_database_arn" {
  description = "ARN of the Glue database"
  value       = aws_glue_catalog_database.chargeback_data.arn
}

output "glue_consolidated_table_name" {
  description = "Name of the consolidated chargebacks table"
  value       = aws_glue_catalog_table.chargebacks_consolidated.name
}

output "glue_landing_table_name" {
  description = "Name of the landing zone table (will be created by crawler)"
  value       = local.landing_table_name
}
