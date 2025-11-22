# =========================================================================
# 1. Security & Permissions
# =========================================================================

# --- RDS Security Group (Sec 2.8) ---
# Allows traffic only from the App Layer
resource "aws_security_group" "quiz_db_sg" {
  name        = "quiz-db-sg"
  vpc_id      = aws_vpc.hydra_vpc.id # References VPC from main.tf
  description = "Security group for Quiz Service RDS"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # References App SG from main.tf
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "quiz-db-sg" }
}

# =========================================================================
# 2. SNS Notification Hub (Sec 2.6 - Modified)
# =========================================================================

# --- SNS Topic  ---
resource "aws_sns_topic" "s3_updates" {
  name         = "quiz-s3-notifications" # 
  display_name = "QuizS3Notifications"   # 
}

# --- SNS Access Policy ---
# Critical: Allows S3 bucket to publish messages to this SNS topic
resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.s3_updates.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3ToPublish"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.s3_updates.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.quiz_storage.arn
          }
        }
      }
    ]
  })
}

# =========================================================================
# 3. S3 Buckets (Sec 2.4)
# =========================================================================

resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

# Random ID to ensure unique bucket names (Global S3 Requirement)
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# --- Quiz Service Storage Bucket [cite: 10] ---
resource "aws_s3_bucket" "quiz_storage" {
  bucket = "quiz-service-storage-dev-56-${random_id.bucket_suffix.hex}"
  tags   = { Name = "Quiz Service Storage" }

}

resource "aws_s3_bucket_versioning" "quiz_storage_versioning" {
  bucket = aws_s3_bucket.quiz_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "quiz_storage_encryption" {
  bucket = aws_s3_bucket.quiz_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# --- S3 Event Notification to SNS [cite: 29, 31] ---
# Triggers SNS when a new object is created
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.quiz_storage.id

  topic {
    topic_arn = aws_sns_topic.s3_updates.arn
    events    = ["s3:ObjectCreated:*"] # 
    id        = "s3-to-sns-trigger"    # 
  }

  depends_on = [aws_sns_topic_policy.default]
}

# --- Lifecycle Rule: Move to Standard-IA after 30 days [cite: 12] ---
resource "aws_s3_bucket_lifecycle_configuration" "quiz_storage_lifecycle" {
  bucket = aws_s3_bucket.quiz_storage.id

  rule {
    id     = "MoveToIA" # [cite: 12]
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA" # [cite: 12]
    }
  }
}

# --- Shared Assets Bucket [cite: 10] ---
resource "aws_s3_bucket" "shared_assets" {
  bucket = "shared-assets-dev-56-${random_id.bucket_suffix.hex}"
  tags   = { Name = "Shared Assets" }
}


resource "aws_s3_bucket_versioning" "shared_assets_versioning" {
  bucket = aws_s3_bucket.shared_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "shared_assets_encryption" {
  bucket = aws_s3_bucket.shared_assets.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "shared_assets_lifecycle" {
  bucket = aws_s3_bucket.shared_assets.id

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
# 4. RDS Database (Sec 2.8)
# =========================================================================

resource "random_password" "db_pass" {
  length  = 16
  special = false
}

# Subnet Group using the 'data_db' subnets defined in main.tf
resource "aws_db_subnet_group" "quiz_db_subnet_group" {
  name       = "main-db-subnet-group"
  subnet_ids = aws_subnet.data_db[*].id

  tags = { Name = "Main DB Subnet Group" }
}

resource "aws_db_instance" "quiz_db" {
  identifier        = "quiz-service-db" # [cite: 4]
  allocated_storage = 20                # [cite: 7]
  storage_type      = "gp3"             # [cite: 7]
  engine            = "postgres"        # [cite: 7]
  engine_version    = "18.1"            # Compatible Postgres version
  instance_class    = "db.t3.medium"    # [cite: 7]
  db_name           = "quizdb"          # [cite: 6]
  username          = "quizadmin"       # [cite: 7]
  password          = "RAGNAROK9090!"

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.quiz_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.quiz_db_sg.id]

  # Availability & Durability [cite: 7]
  multi_az                = true
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = true
  backup_retention_period = 7
}

# =========================================================================
# 5. Outputs
# =========================================================================

output "sns_topic_arn" {
  description = "ARN of the SNS topic for S3 notifications"
  value       = aws_sns_topic.s3_updates.arn
}

output "quiz_db_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.quiz_db.endpoint
}

output "quiz_db_password" {
  description = "Auto-generated password for the RDS instance"
  value       = random_password.db_pass.result
  sensitive   = true
}
