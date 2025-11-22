provider "aws" {
  region                   = "us-east-1"     # e.g., "us-east-1"
  shared_credentials_files = ["credentials"] # Relative path to your credentials file
  profile                  = "default"       # Or "default" if you used the default profile
}


# ==========  ===============================================================
# 1. VPC & Network Foundation [cite: 3, 4]
# =========================================================================

resource "aws_vpc" "hydra_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "Project-Hydra-VPC"
  }
}

# Availability Zones [cite: 6]
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.hydra_vpc.id
  tags   = { Name = "Project-Hydra-IGW" }
}

# =========================================================================
# 2. Subnet Architecture (Segmentation Strategy) 
# =========================================================================

# --- Public Subnets (ALB & NAT) ---
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.hydra_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24" # Using low range for Public
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "Project-Hydra-VPC-subnet-public${count.index + 1}-us-east-1${count.index == 0 ? "a" : "b"}"
  }
}

# --- Private App Layer (Container Cluster) [cite: 44] ---
resource "aws_subnet" "private_app" {
  count             = 2
  vpc_id            = aws_vpc.hydra_vpc.id
  cidr_block        = "10.0.${50 + count.index}.0/24" # 10.0.50.0/24 & 10.0.51.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "private-app-${count.index == 0 ? "a" : "b"}" }
}

# --- Data Persistence Layer (RDS) [cite: 47] ---
resource "aws_subnet" "data_db" {
  count             = 2
  vpc_id            = aws_vpc.hydra_vpc.id
  cidr_block        = "10.0.${60 + count.index}.0/24" # 10.0.60.0/24 & 10.0.61.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "data-db-${count.index == 0 ? "a" : "b"}" }
}

# --- Kafka Streaming Layer [cite: 49] ---
resource "aws_subnet" "kafka_cluster" {
  count             = 2
  vpc_id            = aws_vpc.hydra_vpc.id
  cidr_block        = "10.0.${70 + count.index}.0/24" # 10.0.70.0/24 & 10.0.71.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "kafka-cluster-${count.index == 0 ? "a" : "b"}" }
}

# =========================================================================
# 3. Routing & Gateways [cite: 13]
# =========================================================================

# --- NAT Gateways (High Availability: 1 per AZ) [cite: 16] ---
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "Project-Hydra-NAT-GW-${count.index == 0 ? "A" : "B"}" }
}

# --- Route Tables ---
# Public RT: To IGW [cite: 19]
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.hydra_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "rtb-public-igw" }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private RTs: To NAT GWs [cite: 20, 21]
resource "aws_route_table" "private_rt" {
  count  = 2
  vpc_id = aws_vpc.hydra_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }
  tags = { Name = "Private-RT-AZ-${count.index == 0 ? "A" : "B"}" }
}

# Associate Private Subnets to Private RTs
resource "aws_route_table_association" "app_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}
resource "aws_route_table_association" "data_assoc" {
  count          = 2
  subnet_id      = aws_subnet.data_db[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}
resource "aws_route_table_association" "kafka_assoc" {
  count          = 2
  subnet_id      = aws_subnet.kafka_cluster[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}

# =========================================================================
# 4. Security Groups [cite: 72, 77]
# =========================================================================

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  vpc_id      = aws_vpc.hydra_vpc.id
  description = "Allow Public HTTP Access"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app-cluster-sg"
  vpc_id      = aws_vpc.hydra_vpc.id
  description = "Security group for Application Containers"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "kafka_sg" {
  name        = "kafka-sg"
  vpc_id      = aws_vpc.hydra_vpc.id
  description = "Security group for Kafka and Zookeeper"

  # Allow internal communication within the SG (Kafka <-> Zookeeper)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
  # Allow access from App Cluster (Producers/Consumers)
  ingress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
  # Allow SSH for management (Internal Only)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =========================================================================
# 5. Compute Resources (EC2) [cite: 66, 67]
# =========================================================================

# Key Pair Management (Auto-generates a key file locally)
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "kp" {
  key_name   = "project-hydra-key" # [cite: 81]
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename        = "project-hydra-key.pem"
  content         = tls_private_key.pk.private_key_pem
  file_permission = "0400"
}

# AMI Lookup (Amazon Linux 2023) [cite: 83]
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# --- App Nodes (3 Instances) [cite: 73] ---
resource "aws_instance" "app_nodes" {
  count                       = 3
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"                                        # 
  subnet_id                   = element(aws_subnet.private_app[*].id, count.index) # Distributes across AZs
  key_name                    = aws_key_pair.kp.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = false # [cite: 79]

  tags = { Name = "App-Node-${count.index + 1}" }
}

# --- Kafka Brokers (3 Instances) [cite: 70] ---
resource "aws_instance" "kafka_brokers" {
  count                       = 3
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = element(aws_subnet.kafka_cluster[*].id, count.index)
  key_name                    = aws_key_pair.kp.key_name
  vpc_security_group_ids      = [aws_security_group.kafka_sg.id]
  associate_public_ip_address = false

  tags = { Name = "Kafka-Broker-${count.index + 1}" }
}

# --- Zookeeper Nodes (3 Instances) [cite: 70] ---
resource "aws_instance" "zookeeper_nodes" {
  count                       = 3
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.medium"
  subnet_id                   = element(aws_subnet.kafka_cluster[*].id, count.index)
  key_name                    = aws_key_pair.kp.key_name
  vpc_security_group_ids      = [aws_security_group.kafka_sg.id]
  associate_public_ip_address = false

  tags = { Name = "Zookeeper-${count.index + 1}" }
}

# =========================================================================
# 6. Load Balancing [cite: 84]
# =========================================================================

# --- Public Application Load Balancer (ALB) [cite: 88] ---
resource "aws_lb" "alb" {
  name               = "hydra-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-cluster-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.hydra_vpc.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Register App Nodes to ALB Target Group
resource "aws_lb_target_group_attachment" "app_attach" {
  count            = 3
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_nodes[count.index].id
  port             = 80
}

# --- Internal Network Load Balancer (NLB) for Kafka [cite: 98] ---
resource "aws_lb" "nlb" {
  name               = "hydra-kafka-nlb" # [cite: 134]
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.kafka_cluster[*].id
}

resource "aws_lb_target_group" "kafka_tg" {
  name     = "kafka-cluster-tg" # [cite: 128]
  port     = 9092
  protocol = "TCP"
  vpc_id   = aws_vpc.hydra_vpc.id
}

resource "aws_lb_listener" "kafka_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "9092"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kafka_tg.arn
  }
}

# Register Kafka Brokers to NLB Target Group [cite: 132]
resource "aws_lb_target_group_attachment" "kafka_attach" {
  count            = 3
  target_group_arn = aws_lb_target_group.kafka_tg.arn
  target_id        = aws_instance.kafka_brokers[count.index].id
  port             = 9092
}

# =========================================================================
# 7. Outputs [cite: 155, 159]
# =========================================================================

output "alb_dns_name" {
  description = "Public URL for the App Cluster"
  value       = aws_lb.alb.dns_name
}

output "nlb_dns_name" {
  description = "Internal URL for Kafka Connection"
  value       = aws_lb.nlb.dns_name
} 

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

