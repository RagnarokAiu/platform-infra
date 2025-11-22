# =============================================================================
# MEMBER 3 - Speech-to-Text Service (Phase 1)
# =============================================================================


# ------------------ INPUTS ------------------
variable "vpc_id" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
  description = "Never commit real password"
}

# ------------------ DATA ------------------
data "aws_caller_identity" "current" {}
data "aws_vpc" "selected" { id = var.vpc_id }
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}
data "aws_iam_role" "lab_role" { name = "LabRole" }

# ------------------ RANDOM FOR UNIQUENESS ------------------
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# ------------------ S3 BUCKET (FIXED) ------------------
resource "aws_s3_bucket" "stt_bucket" {
  bucket        = "stt-service-storage-${data.aws_caller_identity.current.account_id}-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.stt_bucket.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "enc" {
  bucket = aws_s3_bucket.stt_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.stt_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------ RDS SECURITY GROUP ------------------
resource "aws_security_group" "stt_db_sg" {
  name   = "stt-db-sg"
  vpc_id = data.aws_vpc.selected.id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "stt_subnet_group" {
  name       = "stt-db-subnet-group"
  subnet_ids = data.aws_subnets.private.ids
}

# ------------------ RDS (COST-OPTIMIZED) ------------------
resource "aws_db_instance" "stt_db" {
  identifier              = "stt-service-db"
  engine                  = "postgres"
  engine_version          = "18.1"
  instance_class          = "db.t3.medium"
  allocated_storage       = 20
  max_allocated_storage   = 20
  storage_encrypted       = true
  username                = "stt_admin"
  password                = var.db_password
  db_name                 = "stt_db"
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  publicly_accessible     = false
  apply_immediately       = true

  db_subnet_group_name    = aws_db_subnet_group.stt_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.stt_db_sg.id]
}

# ------------------ IAM POLICY (THE MISSING PART!) ------------------
resource "aws_iam_policy" "stt_service_policy" {
  name = "STT-Service-Policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [
          aws_s3_bucket.stt_bucket.arn,
          "${aws_s3_bucket.stt_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = data.aws_iam_role.lab_role.name
  policy_arn = aws_iam_policy.stt_service_policy.arn
}

# ------------------ OUTPUTS ------------------
output "s3_bucket_name" { value = aws_s3_bucket.stt_bucket.id }
output "db_endpoint"    { value = aws_db_instance.stt_db.endpoint }

output "db_sg_id"       { value = aws_security_group.stt_db_sg.id }

