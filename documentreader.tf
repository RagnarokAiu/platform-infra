provider "aws" {
  region = "us-east-1"
  shared_credentials_files =["Credentials"]
 profile="default"
}

# ---------------------------------------------------------
# VARIABLES (For Network Configuration)
# ---------------------------------------------------------
variable "vpc_id" {
  description = "VPC ID where the DB will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of Private Subnet IDs for the RDS Subnet Group"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of Private Subnet CIDRs to allow traffic from"
  type        = list(string)
}

# ---------------------------------------------------------
# 1. IAM (Sec 2.1): Document Reader Role (RBAC)
# ---------------------------------------------------------

# A. The Identity (Role): Who is this?
# Defines the "Trust Policy" - permitting an AWS Service (e.g., EC2) to assume this role.
resource "aws_iam_role" "doc_reader_role" {
  name = "document-reader-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com" # Change to "ecs-tasks.amazonaws.com" if using containers
      }
    }]
  })
}

# B. The Permissions (Policy): What can they do?
# Specifically allows reading/writing to the Document S3 Bucket.
resource "aws_iam_policy" "doc_reader_policy" {
  name        = "document-reader-policy"
  description = "Permissions for Document Reader Service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.doc_reader_storage.arn,       # Access to the bucket itself
          "${aws_s3_bucket.doc_reader_storage.arn}/*" # Access to files inside
        ]
      }
    ]
  })
}

# C. The Connection (RBAC): Attach Permission to Identity
resource "aws_iam_role_policy_attachment" "attach_doc_reader" {
  role       = aws_iam_role.doc_reader_role.name
  policy_arn = aws_iam_policy.doc_reader_policy.arn
}

# ---------------------------------------------------------
# 2. S3 (Sec 2.4): Document Reader Storage
# ---------------------------------------------------------

resource "aws_s3_bucket" "doc_reader_storage" {
  # Bucket names must be globally unique. Adding a random suffix ensures this.
  bucket        = "document-reader-storage-${random_string.suffix.result}"
  force_destroy = true 

  tags = {
    Name = "document-reader-storage"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encrypt" {
  bucket = aws_s3_bucket.doc_reader_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "s3_block_public" {
  bucket = aws_s3_bucket.doc_reader_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ---------------------------------------------------------
# 3. RDS (Sec 2.8): Document Reader DB (PostgreSQL)
# ---------------------------------------------------------

# Security Group: Allow traffic ONLY from Private Subnets on Port 5432
resource "aws_security_group" "rds_sg" {
  name        = "document-reader-db-sg"
  description = "Allow PostgreSQL access from private subnets"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "document-reader-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "doc_reader_db" {
  identifier             = "document-reader-db"
  engine                 = "postgres"
  engine_version         = "15"    # Latest stable version
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  
  username               = "dbadmin"
  password               = "ChangeMe123!" # Ideally, use AWS Secrets Manager
  
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # --- Requirements Configuration ---
  multi_az                = true            # Requirement: Multi-AZ
  storage_encrypted       = true            # Requirement: Encryption
  backup_retention_period = 7               # Requirement: Backups (7 days)
  skip_final_snapshot     = true            # Set false for production
}