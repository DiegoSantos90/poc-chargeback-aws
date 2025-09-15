# Chargeback System Deployment Guide

## Prerequisites

1. **AWS CLI configured** with appropriate permissions
2. **Terraform** installed (version >= 1.0)
3. **AWS Account** with the following services available:
   - Lambda
   - S3
   - Step Functions
   - SQS
   - SNS
   - Secrets Manager
   - CloudWatch

## Deployment Steps

### 1. Clone the Repository
```bash
git clone <repository-url>
cd poc-chargeback-aws
```

### 2. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
```

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Plan Deployment
```bash
terraform plan
```

### 5. Deploy Infrastructure
```bash
terraform apply
```

### 6. Configure FTP Credentials
After deployment, update the FTP credentials in AWS Secrets Manager:

```bash
aws secretsmanager update-secret \
  --secret-id chargeback-ftp-credentials-dev \
  --secret-string '{
    "host": "your-ftp-server.com",
    "username": "your-username",
    "password": "your-password",
    "port": "21",
    "directory": "/chargebacks"
  }'
```

## Usage

### 1. Upload Chargeback Data
Upload JSON files to the raw data S3 bucket under the `incoming/` prefix:

```bash
aws s3 cp examples/sample_chargeback_data.json s3://chargeback-raw-data-dev-XXXXXXXX/incoming/
```

### 2. Monitor Processing
- Check CloudWatch logs for Lambda functions
- Monitor Step Functions execution in AWS Console
- View dashboard: https://console.aws.amazon.com/cloudwatch/home#dashboards

### 3. Check Results
- Processed CSV files will be in the processed CSV bucket
- Notifications will be sent via SNS topics

## System Limits

- **Maximum CSV files per batch**: 4 (configurable)
- **Lambda timeout**: 5 minutes for processing functions
- **File retention**: 30 days for old versions
- **Log retention**: 14 days

## Monitoring

### CloudWatch Dashboard
The system includes a pre-configured CloudWatch dashboard showing:
- Lambda function duration and errors
- Step Functions execution status
- SQS queue metrics

### Alarms
Automatic alarms are configured for:
- Lambda function errors
- Step Functions execution failures
- High SQS queue depth

## Troubleshooting

### Common Issues

1. **Lambda timeout errors**: Increase timeout in `lambda.tf`
2. **FTP connection failures**: Verify credentials in Secrets Manager
3. **S3 permissions**: Check IAM roles and policies

### Logs Location
- Lambda logs: `/aws/lambda/[function-name]`
- Step Functions logs: `/aws/stepfunctions/chargeback-processing-dev`

### Testing
Use the provided sample data file to test the system:
```bash
aws s3 cp examples/sample_chargeback_data.json s3://[raw-data-bucket]/incoming/test-$(date +%s).json
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Security Considerations

1. **FTP Credentials**: Stored securely in AWS Secrets Manager
2. **S3 Encryption**: All buckets use server-side encryption
3. **IAM Permissions**: Least privilege access for all components
4. **VPC**: Consider deploying Lambda functions in VPC for enhanced security

## Cost Optimization

- Lambda functions are billed per execution
- S3 storage costs are minimal for small files
- Consider setting up S3 lifecycle policies for long-term storage