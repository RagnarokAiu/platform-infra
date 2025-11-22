# =========================================================================
# Chat Service Resources
# =========================================================================

# =========================================================================
# 1. Security & Permissions
# =========================================================================

# --- RDS Security Group ---
resource "aws_security_group" "chat_db_sg" {
  name        = "chat-db-sg"
  vpc_id      = aws_vpc.hydra_vpc.id
  description = "Security group for Chat Service RDS"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "chat-db-sg" }
}

/*
# --- IAM Role ---
resource "aws_iam_role" "chat_service_role" {
  name = "chat-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "chat_s3_policy" {
  name        = "chat-service-s3-policy"
  description = "Allow Chat Service to access its own bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
      Effect = "Allow"
      Resource = [
        aws_s3_bucket.chat_storage.arn,
        "${aws_s3_bucket.chat_storage.arn}/*"
      ]
    }]
  })
}
*/

# =========================================================================
# 2. S3 Buckets
# =========================================================================

resource "aws_kms_key" "chat_key" {
  description             = "KMS key for Chat Service encryption"
  deletion_window_in_days = 10
}

# --- Chat Service Storage Bucket ---
resource "aws_s3_bucket" "chat_storage" {
  bucket = "chat-service-storage-dev-56-${random_id.bucket_suffix.hex}"
  tags   = { Name = "Chat Service Storage" }
}

resource "aws_s3_bucket_versioning" "chat_storage_versioning" {
  bucket = aws_s3_bucket.chat_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "chat_storage_encryption" {
  bucket = aws_s3_bucket.chat_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.chat_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# --- Lifecycle Rule: Move to Standard-IA after 30 days ---
resource "aws_s3_bucket_lifecycle_configuration" "chat_storage_lifecycle" {
  bucket = aws_s3_bucket.chat_storage.id

  rule {
    id     = "MoveToIA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# =========================================================================
# 3. RDS Database
# =========================================================================

resource "aws_db_instance" "chat_db" {
  identifier        = "chat-service-db"
  allocated_storage = 20
  storage_type      = "gp3"
  engine            = "postgres"
  engine_version    = "18.1"
  instance_class    = "db.t3.medium"
  db_name           = "chatdb"
  username          = "chatadmin"
  password          = "RAGNAROK9090!"

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.quiz_db_subnet_group.name # Reusing subnet group from quizservice.tf
  vpc_security_group_ids = [aws_security_group.chat_db_sg.id]

  # Availability & Durability
  multi_az                = true
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = true
  backup_retention_period = 7
}

# =========================================================================
# 4. Outputs
# =========================================================================

output "chat_db_endpoint" {
  description = "Connection endpoint for Chat Service RDS"
  value       = aws_db_instance.chat_db.endpoint
}

output "chat_s3_bucket_name" {
  description = "Name of the S3 bucket for Chat logs"
  value       = aws_s3_bucket.chat_storage.id
}
