# =========================================================================
# TTS Service Resources
# =========================================================================

# =========================================================================
# 1. S3 Buckets
# =========================================================================

resource "aws_kms_key" "tts_key" {
  description             = "Key for TTS bucket encryption"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "tts_storage" {
  bucket = "tts-service-storage-dev-56-${random_id.bucket_suffix.hex}"
  tags   = { Name = "TTS Service Storage" }
}

resource "aws_s3_bucket_versioning" "tts_storage_versioning" {
  bucket = aws_s3_bucket.tts_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tts_storage_encryption" {
  bucket = aws_s3_bucket.tts_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tts_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tts_storage_lifecycle" {
  bucket = aws_s3_bucket.tts_storage.id

  rule {
    id     = "MoveToIA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}
