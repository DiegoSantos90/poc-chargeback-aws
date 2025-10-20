# ============================================================================
# Phase 1: S3 Buckets
# ============================================================================
# Buckets para armazenar arquivos de dados

# ----------------------------------------------------------------------------
# S3 Bucket for Parquet Files (dados processados/otimizados)
# ----------------------------------------------------------------------------

resource "aws_s3_bucket" "parquet_files" {
  bucket = "${var.project_name}-parquet-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  # force_destroy permite destruir o bucket mesmo com objetos dentro
  # CUIDADO: Em produção, considere false para evitar perda acidental de dados
  force_destroy = var.environment == "dev" ? true : false
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-parquet-bucket-${var.environment}"
      Environment = var.environment
      DataType    = "Parquet"
    }
  )
}

# ----------------------------------------------------------------------------
# S3 Bucket for CSV Files (dados brutos/exports)
# ----------------------------------------------------------------------------

resource "aws_s3_bucket" "csv_files" {
  bucket = "${var.project_name}-csv-${var.environment}-${data.aws_caller_identity.current.account_id}"
  
  # force_destroy permite destruir o bucket mesmo com objetos dentro
  # CUIDADO: Em produção, considere false para evitar perda acidental de dados
  force_destroy = var.environment == "dev" ? true : false
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-csv-bucket-${var.environment}"
      Environment = var.environment
      DataType    = "CSV"
    }
  )
}

# ----------------------------------------------------------------------------
# S3 Bucket Versioning (mantém histórico de mudanças)
# ----------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "parquet_versioning" {
  bucket = aws_s3_bucket.parquet_files.id
  
  versioning_configuration {
    status = "Enabled"
  }
  
  # Versioning permite:
  # - Recuperar versões anteriores de arquivos
  # - Proteção contra exclusão acidental
  # - Auditoria de mudanças
}

resource "aws_s3_bucket_versioning" "csv_versioning" {
  bucket = aws_s3_bucket.csv_files.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# ----------------------------------------------------------------------------
# Data Source: AWS Account ID (para nomes únicos de buckets)
# ----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# ============================================================================
# IMPORTANTE: Nomes de buckets S3 são GLOBALMENTE únicos
# Por isso usamos account_id no nome do bucket
# ============================================================================
