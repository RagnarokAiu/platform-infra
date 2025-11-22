Project Hydra: Phase 1 Infrastructure Overview

The Foundation We began by building a robust cloud network called Project-Hydra-VPC. Instead of a basic setup, we designed a secure, multi-tiered network spread across two Availability Zones to ensure High Availability. We implemented a "Defense in Depth" strategy by segmenting the network into four distinct layers: a Public layer for entry, a Private Application layer for our code, a dedicated Data layer for databases, and a specialized Kafka layer for high-speed event streaming.

Compute & Connectivity To power the platform, we deployed 9 EC2 servers (t3.medium) running Amazon Linux. These include three nodes for our containerized applications, three for the Kafka message brokers, and three for Zookeeper management. To manage traffic, we set up two types of Load Balancers: a Public Application Load Balancer (ALB) to serve as the secure front door for users, and an Internal Network Load Balancer (NLB) to handle high-performance traffic between our internal microservices and the Kafka cluster.


Data & Storage For data storage, we provisioned RDS PostgreSQL databases configured with Multi-AZ for backup redundancy. We also created specific S3 buckets (like quiz-service-storage-56 and shared-assets-56) to handle file storage for the various services.



Security & Adaptation Security was a primary focus. We used Network ACLs and Security Groups to strictly isolate our databases and servers from the public internet. However, we faced a challenge with the AWS Academy lab environment, which restricted our ability to create custom IAM Roles. This prevented us from using standard AWS Lambda triggers. We adapted by implementing Operational RBAC (Role-Based Access Control) to enforce permissions at the team level and replaced the planned Lambda architecture with Amazon SNS (Simple Notification Service) to successfully handle event-driven notifications despite the lab limitations.
