# S3 Module — Main Configuration
#
# This module creates a production-grade S3 bucket with:
#   - Versioning enabled
#   - Server-side encryption (AES-256)
#   - Public access fully blocked
#   - Lifecycle rules to transition old versions to cheaper storage

resource "aws_s3_bucket" "this" {
  bucket = "${var.project_name}-${var.environment}-${var.bucket_suffix}"

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-${var.bucket_suffix}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Block ALL public access — security best practice
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning to protect against accidental deletion
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Server-Side Encryption — always encrypt data at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true # Reduces cost of SSE-KMS if switched later
  }
}

# Lifecycle rule — move old versions to Glacier to save cost
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.versioning_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
