# STT Service Resources
# 1. Security & Permissions
# --- RDS Security Group (Sec 2.8 & 5.2) ---
resource "aws_security_group" "stt_db_sg" {
  name        = "stt-db-sg"
  vpc_id      = aws_vpc.hydra_vpc.id
  description = "Security group for STT Service RDS"

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

  tags = { Name = "stt-db-sg" }
}

# --- IAM Role (Sec 2.1) ---
/*resource "aws_iam_role" "stt_service_role" {
  name = "stt-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # Assuming EC2/App layer needs this role
        }
      }
    ]
  })
}

resource "aws_iam_policy" "stt_service_policy" {
  name        = "stt-service-policy"
  description = "Policy for STT Service to access S3 and RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.stt_storage.arn,
          "${aws_s3_bucket.stt_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = aws_db_instance.stt_db.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "stt_service_attach" {
  role       = aws_iam_role.stt_service_role.name
  policy_arn = aws_iam_policy.stt_service_policy.arn
}*/

# 2. S3 Buckets (Sec 2.4)
resource "aws_kms_key" "stt_key" {
  description             = "Key for STT bucket encryption"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "stt_storage" {
  bucket = "stt-service-storage-dev-56-${random_id.bucket_suffix.hex}"
  tags   = { Name = "STT Service Storage" }
}

resource "aws_s3_bucket_versioning" "stt_storage_versioning" {
  bucket = aws_s3_bucket.stt_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "stt_storage_encryption" {
  bucket = aws_s3_bucket.stt_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.stt_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "stt_storage_lifecycle" {
  bucket = aws_s3_bucket.stt_storage.id

  rule {
    id     = "MoveToIA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# 3. RDS Database (Sec 2.8 & 5.2)
resource "aws_db_instance" "stt_db" {
  identifier        = "stt-db"
  allocated_storage = 20
  storage_type      = "gp3"
  engine            = "postgres"
  engine_version    = "18.1"
  instance_class    = "db.t3.medium"
  db_name           = "sttdb"
  username          = "sttadmin"
  password          = "RAGNAROK9090!"

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.quiz_db_subnet_group.name 
  vpc_security_group_ids = [aws_security_group.stt_db_sg.id]

  # Availability & Durability
  multi_az                = true
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = true
  backup_retention_period = 7
}
