# =========================================================================
# Document Reader Service Resources
# =========================================================================

# =========================================================================
# 1. Security & Permissions
# =========================================================================

# --- RDS Security Group (Sec 2.8) ---
resource "aws_security_group" "doc_reader_db_sg" {
  name        = "doc-reader-db-sg"
  vpc_id      = aws_vpc.hydra_vpc.id
  description = "Security group for Document Reader Service RDS"

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

  tags = { Name = "doc-reader-db-sg" }
}

# --- IAM Role (Sec 2.1) ---
resource "aws_iam_role" "document_reader_role" {
  name = "document-reader-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "document_reader_policy" {
  name        = "document-reader-policy"
  description = "Policy for Document Reader Service to access S3 and RDS"

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
          aws_s3_bucket.document_reader_storage.arn,
          "${aws_s3_bucket.document_reader_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = aws_db_instance.document_reader_db.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "document_reader_attach" {
  role       = aws_iam_role.document_reader_role.name
  policy_arn = aws_iam_policy.document_reader_policy.arn
}

# =========================================================================
# 2. S3 Buckets (Sec 2.4)
# =========================================================================

resource "aws_kms_key" "doc_reader_key" {
  description             = "Key for Document Reader bucket encryption"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "document_reader_storage" {
  bucket = "document-reader-storage-dev-56-${random_id.bucket_suffix.hex}"
  tags   = { Name = "Document Reader Storage" }
}

resource "aws_s3_bucket_versioning" "document_reader_storage_versioning" {
  bucket = aws_s3_bucket.document_reader_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "document_reader_storage_encryption" {
  bucket = aws_s3_bucket.document_reader_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.doc_reader_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "document_reader_storage_lifecycle" {
  bucket = aws_s3_bucket.document_reader_storage.id

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
# 3. RDS Database (Sec 2.8)
# =========================================================================

resource "aws_db_instance" "document_reader_db" {
  identifier        = "document-reader-db"
  allocated_storage = 20
  storage_type      = "gp3"
  engine            = "postgres"
  engine_version    = "18.1"
  instance_class    = "db.t3.medium"
  db_name           = "docreaderdb"
  username          = "docreaderadmin"
  password          = "RAGNAROK9090!"

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.quiz_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.doc_reader_db_sg.id]

  # Availability & Durability
  multi_az                = true
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = true
  backup_retention_period = 7
}
