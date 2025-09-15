# Chargeback System - AWS POC

A comprehensive chargeback processing system built on AWS services that processes chargeback data and sends up to 4 CSV files to card company FTP servers.

## 🏗️ Architecture Overview

This system leverages serverless AWS services to create a scalable and reliable chargeback processing pipeline:

- **S3**: Raw data storage and processed CSV file storage
- **Lambda**: Data processing, CSV generation, and FTP delivery
- **Step Functions**: Workflow orchestration with error handling
- **SQS**: Message queuing for reliable processing
- **SNS**: Notifications and alerts
- **Secrets Manager**: Secure FTP credential storage
- **CloudWatch**: Comprehensive monitoring and logging

## 🚀 Key Features

- **Scalable**: Handles varying volumes of chargeback data automatically
- **Reliable**: Built-in retry mechanisms and error handling
- **Secure**: Encrypted storage and secure credential management
- **Monitored**: Real-time dashboards and alerting
- **Cost-Effective**: Pay-per-use serverless architecture
- **Compliant**: Maximum 4 CSV files per batch as required

## 📋 Quick Start

1. **Deploy Infrastructure**
   ```bash
   terraform init
   terraform apply
   ```

2. **Configure FTP Credentials**
   ```bash
   aws secretsmanager update-secret --secret-id chargeback-ftp-credentials-dev --secret-string '{"host":"ftp.example.com","username":"user","password":"pass","port":"21"}'
   ```

3. **Upload Test Data**
   ```bash
   aws s3 cp examples/sample_chargeback_data.json s3://[raw-data-bucket]/incoming/
   ```

## 📁 Project Structure

```
├── ARCHITECTURE.md          # Detailed system architecture
├── DEPLOYMENT.md           # Deployment guide
├── main.tf                 # Main Terraform configuration
├── s3.tf                   # S3 buckets configuration
├── lambda.tf               # Lambda functions
├── step_functions.tf       # Workflow orchestration
├── iam.tf                  # IAM roles and policies
├── messaging.tf            # SQS and SNS configuration
├── monitoring.tf           # CloudWatch monitoring
├── outputs.tf              # Terraform outputs
├── lambda_functions/       # Lambda source code
│   ├── data_processor.py
│   ├── csv_generator.py
│   └── ftp_uploader.py
└── examples/               # Sample data and configurations
```

## 🔄 Data Flow

1. Raw chargeback data uploaded to S3 (`incoming/` prefix)
2. S3 event triggers Step Functions workflow
3. Data processor validates and processes input
4. CSV generator creates up to 4 CSV files
5. FTP uploader sends files to card company servers
6. Success/failure notifications sent via SNS

## 📊 Monitoring

- **CloudWatch Dashboard**: Real-time metrics and logs
- **Automated Alarms**: Lambda errors and Step Function failures
- **Comprehensive Logging**: All components with structured logs

## 🛡️ Security

- S3 server-side encryption
- IAM least privilege access
- Secrets Manager for FTP credentials
- VPC deployment ready (optional)

## 📚 Documentation

- [Architecture Details](ARCHITECTURE.md)
- [Deployment Guide](DEPLOYMENT.md)
- [API Documentation](docs/api.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
