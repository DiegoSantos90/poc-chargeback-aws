# Chargeback System Architecture

## Overview
This system design implements a scalable, reliable chargeback processing system using AWS services. The system processes chargeback data, generates up to 4 CSV files per batch, and delivers them to card company FTP servers.

## System Architecture

### Core Components

1. **Data Ingestion Layer**
   - Amazon S3: Raw chargeback data storage
   - AWS Lambda: Data validation and preprocessing
   - Amazon SQS: Message queuing for processing requests

2. **Processing Layer**
   - AWS Step Functions: Workflow orchestration
   - AWS Lambda: CSV generation and processing logic
   - Amazon S3: Processed CSV file storage

3. **Delivery Layer**
   - AWS Lambda: FTP delivery functions
   - Amazon SNS: Notification system
   - AWS Secrets Manager: FTP credentials management

4. **Monitoring & Logging**
   - Amazon CloudWatch: Logs and metrics
   - AWS X-Ray: Distributed tracing
   - Amazon SNS: Alert notifications

## Data Flow

1. **Ingestion**: Raw chargeback data arrives in S3 bucket
2. **Trigger**: S3 event triggers Step Function workflow
3. **Processing**: Lambda functions process data and generate CSV files (max 4 per batch)
4. **Validation**: CSV files are validated for format and content
5. **Delivery**: Lambda functions upload CSV files to card company FTP servers
6. **Notification**: Success/failure notifications sent via SNS
7. **Monitoring**: All activities logged to CloudWatch

## Key Features

- **Scalability**: Handles varying volumes of chargeback data
- **Reliability**: Built-in retry mechanisms and error handling
- **Security**: Encrypted data storage and secure FTP credential management
- **Monitoring**: Comprehensive logging and alerting
- **Cost-Effective**: Serverless architecture with pay-per-use model

## File Limits
- Maximum 4 CSV files per processing batch
- Configurable file size limits
- Automatic batching for large datasets

## Error Handling
- Dead letter queues for failed processing
- Exponential backoff retry strategies
- Comprehensive error logging and alerting