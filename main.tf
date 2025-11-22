# =========================================================================
# 8. IAM & RBAC 
# =========================================================================

# --- User Management (RBAC) ---

# 1. Create the Developer Group
resource "aws_iam_group" "hydra_developers" {
  name = "hydra-developers-group"
}

# 2. Attach a Policy (Permissions) to the Group
# Giving them "PowerUserAccess" (allows most things except IAM management)
resource "aws_iam_group_policy_attachment" "dev_access" {
  group      = aws_iam_group.hydra_developers.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# 3. Create Users for Members 2 through 6
resource "aws_iam_user" "team_members" {
  count = 5
  name  = "member-${count.index + 2}" # Creates member-2, member-3, etc.
  tags = {
    Project = "Hydra"
    Role    = "Service-Owner"
  }
}

# 4. Add Users to the Developer Group
resource "aws_iam_user_group_membership" "add_to_group" {
  count = 5
  user  = aws_iam_user.team_members[count.index].name
  groups = [
    aws_iam_group.hydra_developers.name
  ]
}

# --- EC2 Instance Roles (Foundational Roles) ---

# Role that allows EC2 instances to talk to AWS services (e.g., SSM, CloudWatch)
resource "aws_iam_role" "ec2_base_role" {
  name = "hydra-ec2-base-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "hydra-ec2-instance-profile"
  role = aws_iam_role.ec2_base_role.name
}

# =========================================================================
# 9. RDS: User Management Database (FIXED)
# =========================================================================

resource "aws_security_group" "rds_sg" {
  name        = "hydra-rds-sg"
  vpc_id      = aws_vpc.hydra_vpc.id
  description = "Access to User Management DB"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
}

resource "aws_db_subnet_group" "user_db_subnet_group" {
  name       = "hydra-user-db-subnet-group"
  subnet_ids = aws_subnet.data_db[*].id
  tags       = { Name = "Hydra DB Subnet Group" }
}

resource "aws_db_instance" "user_db" {
  identifier             = "hydra-user-management-db"
  allocated_storage      = 20 # FIX: Minimum is 20 GB
  db_name                = "user_management"
  engine                 = "postgres"
  engine_version         = "16.1" # FIX: Changed from 16.3 to 16.1
  instance_class         = "db.t3.micro"
  username               = "admin_hydra"
  password               = "ChangeMe123!"
  parameter_group_name   = "default.postgres16"
  skip_final_snapshot    = true
  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.user_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

# =========================================================================
# 10. Network Security ACLs (AWS WAF) 
# =========================================================================

# 1. Define the Web ACL (Access Control List)
resource "aws_wafv2_web_acl" "hydra_waf" {
  name        = "hydra-main-acl"
  description = "WAF for Project Hydra ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "hydra-waf-metrics"
    sampled_requests_enabled   = true
  }

  # Rule: Block Common Vulnerabilities (AWS Managed Rules)
  rule {
    name     = "AWS-Common-Rule-Set"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
      sampled_requests_enabled   = true
    }
  }
}

# 2. Associate the ACL with your existing ALB
# Note: 'aws_lb.alb.arn' refers to the ALB created in your previous script
resource "aws_wafv2_web_acl_association" "alb_waf_assoc" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.hydra_waf.arn
}
