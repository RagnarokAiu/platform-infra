# Platform Infra - Project Hydra

## Overview

**Platform Infra** (codenamed **Project Hydra**) is a comprehensive Infrastructure-as-Code (IaC) repository built with **Terraform**. It provisions a robust, scalable, and secure cloud environment on **AWS** to support a microservices-based architecture. The platform includes a dedicated VPC, segmented subnets, managed databases (RDS), object storage (S3), event-driven messaging (SNS), and container orchestration infrastructure.

## Architecture Highlights

The infrastructure is designed with high availability, security, and scalability in mind:

*   **VPC & Networking**: A custom VPC (`10.0.0.0/16`) with public and private subnets across multiple Availability Zones (AZs) for fault tolerance.
*   **Compute Layer**:
    *   **App Nodes**: EC2 instances for hosting application containers.
    *   **Kafka Cluster**: Dedicated brokers and Zookeeper nodes for event streaming.
    *   **Load Balancing**: Public ALB for incoming HTTP traffic and internal NLB for Kafka communication.
*   **Data Persistence**:
    *   **Relational Databases**: Managed **PostgreSQL** (RDS) instances for individual services (User, Quiz, Chat, STT, Document Reader).
    *   **Object Storage**: Secure **S3 buckets** with encryption (KMS), versioning, and lifecycle policies for service data.
    *   **Block Storage**: Encrypted **EBS volumes** for Kafka and application data persistence, backed by automated DLM snapshots.
*   **Security**:
    *   **Network Security**: Strict Security Groups and Network ACLs.
    *   **WAF**: AWS WAFv2 protecting the public load balancer.
    *   **Encryption**: KMS-managed keys for S3 and EBS encryption.
    *   **IAM**: Least-privilege roles (using AWS Academy `LabRole` for compatibility).

## Services Infrastructure

The project supports the following distinct microservices, each with its own dedicated resources:

| Service | Database (RDS) | Storage (S3) | Key Features |
| :--- | :--- | :--- | :--- |
| **User Management** | `userdb` | N/A | Core user identity and auth. |
| **Quiz Service** | `quizdb` | `quiz-service-storage` | SNS notifications for S3 uploads. |
| **Chat Service** | `chatdb` | `chat-service-storage` | Dedicated secure storage for chat logs. |
| **STT Service** | `sttdb` | `stt-service-storage` | Speech-to-Text processing storage. |
| **TTS Service** | `N/A` | `tts-service-storage` | Text-to-Speech audio storage. |
| **Document Reader** | `docreaderdb` | `document-reader-storage` | Document processing and storage. |

## Prerequisites

*   **Terraform**: v1.0+
*   **AWS CLI**: Configured with appropriate credentials.
*   **AWS Account**: Access to an AWS environment (compatible with AWS Academy Learner's Lab).

## Getting Started

1.  **Clone the Repository**:
    ```bash
    git clone <repository-url>
    cd platform-infra
    ```

2.  **Initialize Terraform**:
    Downloads providers and initializes the backend.
    ```bash
    terraform init
    ```

3.  **Review the Plan**:
    See what resources will be created.
    ```bash
    terraform plan
    ```

4.  **Apply Configuration**:
    Provision the infrastructure.
    ```bash
    terraform apply
    ```

## Project Structure

*   `main.tf`: Core networking (VPC, Subnets, IGW, NAT), Compute (EC2), and Load Balancers.
*   `ebs.tf`: EBS volumes for Kafka/App nodes and DLM backup policies.
*   `quizservice.tf`: Resources for the Quiz Service (RDS, S3, SNS).
*   `chatservice.tf`: Resources for the Chat Service.
*   `stt.tf`: Resources for the Speech-to-Text Service.
*   `tts.tf`: Resources for the Text-to-Speech Service.
*   `documentreader.tf`: Resources for the Document Reader Service.
*   `credentials`: AWS credentials file (ensure this is configured correctly).

## Security & Compliance

*   **Encryption at Rest**: All S3 buckets and EBS volumes are encrypted using AWS KMS.
*   **Network Isolation**: Databases and application nodes reside in private subnets, accessible only via the Load Balancer or Bastion (if configured).
*   **Backup Strategy**: Automated daily snapshots for EBS volumes via Data Lifecycle Manager (DLM).

## License

This project is licensed under the MIT License.
