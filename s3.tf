# S3 Buckets for data storage
resource "aws_s3_bucket" "raw_data" {
  bucket = "${var.project_name}-raw-data-${var.environment}-${random_string.bucket_suffix.result}"
  tags   = local.common_tags
}

resource "aws_s3_bucket" "processed_csvs" {
  bucket = "${var.project_name}-processed-csvs-${var.environment}-${random_string.bucket_suffix.result}"
  tags   = local.common_tags
}

resource "aws_s3_bucket" "failed_files" {
  bucket = "${var.project_name}-failed-files-${var.environment}-${random_string.bucket_suffix.result}"
  tags   = local.common_tags
}

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "processed_csvs" {
  bucket = aws_s3_bucket.processed_csvs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_csvs" {
  bucket = aws_s3_bucket.processed_csvs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "processed_csvs" {
  bucket = aws_s3_bucket.processed_csvs.id

  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}