Project Hydra: Cloud-Native Microservices Platform

📖 Overview

Project Hydra is a scalable, high-availability cloud infrastructure designed to host a suite of AI-powered microservices (Text-to-Speech, Speech-to-Text, Chat, Document Reader, and Quiz Generator).

This repository contains the Infrastructure as Code (IaC) for Phase 1, which establishes the secure networking foundation, compute clusters, and database persistence layers required for the application.

🏗️ Network Architecture (VPC)

We moved away from a flat network topology to a segmented, multi-tier architecture designed for Defense in Depth. The infrastructure is deployed across 2 Availability Zones (US-East-1a / US-East-1b) for High Availability.

VPC Name: Project-Hydra-VPC

CIDR Block: 10.0.0.0/16

Subnet Segmentation Strategy

Tier

IP Range (AZ-A)

IP Range (AZ-B)

Purpose

Access

Public

10.0.0.0/24

10.0.1.0/24

Ingress Layer. Hosts Application Load Balancer (ALB) and NAT Gateways.

Public Internet (IGW)

Private App

10.0.50.0/24

10.0.51.0/24

Compute Layer. Hosts Docker Application Nodes.

Internal Only (NAT Egress)

Data

10.0.60.0/24

10.0.61.0/24

Persistence Layer. Hosts RDS Databases.

Restricted to App Tier

Kafka

10.0.70.0/24

10.0.71.0/24

Streaming Layer. Dedicated high-performance lane for Kafka & Zookeeper.

Internal Only

💻 Compute & Connectivity

EC2 Clusters

We provisioned 9 Core Instances (t3.medium) running Amazon Linux 2023, completely isolated in private subnets:

Kafka Cluster: 3 Brokers + 3 Zookeeper Nodes (Event Streaming).

App Cluster: 3 Application Nodes (Container Orchestration).

Load Balancing Strategy

Public Application Load Balancer (ALB): Handles HTTP/HTTPS traffic from users and forwards it to the App Cluster. Acts as the secure "Front Door."

Internal Network Load Balancer (NLB): Handles high-throughput TCP traffic (Port 9092). Provides a stable internal DNS for microservices to connect to the Kafka Cluster.

🛡️ Security & Access Control

Security Layers

Network ACLs: Stateless traffic filtering at the subnet boundary.

Security Groups: Stateful firewalls at the instance level (e.g., RDS allows traffic on port 5432 only from the App Security Group).

⚠️ Architecture Adaptations (Lab Constraints)

Due to the restrictions of the AWS Academy Learner Lab environment (specifically the inability to perform iam:CreateRole), we implemented the following strategic adaptations:

Operational RBAC:
Since we cannot create custom IAM Users/Groups via Terraform, we enforce Role-Based Access Control at the process level.

Team Lead (Member 1): Owns Main Branch & Terraform State.

Developers: Own Application Code & Service configurations.

Governance: Enforced via GitHub Branch Protection rules.

Event-Driven Architecture (SNS vs. Lambda):

Constraint: We could not deploy a Lambda function to process S3 uploads because we lacked permissions to create the execution role.

Solution: We pivoted to Amazon SNS (Simple Notification Service). S3 events now publish directly to an SNS Topic, ensuring our event-driven workflow functions correctly without violating lab policies.

📂 Storage Resources

Database Layer (RDS Multi-AZ)

User Management DB: Shared PostgreSQL instance.

Service DBs: Dedicated databases for Quiz, Chat, STT, and Document services.

Note: All DBs are configured with Multi-AZ redundancy and strict Security Group locking.

Object Storage (S3)

quiz-service-storage: Stores generated quizzes and user uploads.

shared-assets: Stores common frontend assets.

Configuration: Lifecycle rules enabled for cost optimization.

👥 Team & Responsibilities

Role

Member

Responsibilities

Team Lead / Platform

Member 1

VPC, Core Network, Terraform, CI/CD, Kafka Setup

Service Owner

Member 2

TTS Service (Text-to-Speech)

Service Owner

Member 3

STT Service (Speech-to-Text)

Service Owner

Member 4

Chat Service

Service Owner

Member 5

Document Reader Service

Security Lead

Member 6

Quiz Service, JWT Auth, Secrets Manager

🚀 Deployment

To deploy the infrastructure, ensure you have the project-hydra-key.pem and AWS Credentials configured.

# 1. Initialize Terraform
terraform init

# 2. Plan the deployment (Check for errors)
terraform plan

# 3. Apply the infrastructure
terraform apply


Access Points

Public API: http://hydra-public-alb-xxxx.us-east-1.elb.amazonaws.com

Bastion Host: ssh -i key.pem ec2-user@<BASTION_IP>

Project Hydra - Phase 1 Documentation
