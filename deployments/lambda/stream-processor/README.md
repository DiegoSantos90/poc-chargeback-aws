# Lambda Stream Processor README

## 📦 How to Build and Deploy

### 1. Install Dependencies

```bash
cd deployments/lambda/stream-processor
pip install -r requirements.txt -t .
```

### 2. Create Deployment Package

```bash
zip -r ../stream-processor.zip .
```

### 3. Deploy via Terraform

The deployment package will be automatically picked up by Terraform:

```bash
cd ../../../infrastructure/terraform
terraform apply
```

## 🧪 Local Testing

You can test the Lambda function locally:

```bash
python lambda_function.py
```

## 📝 Code Structure

- `lambda_function.py` - Main Lambda handler
- `requirements.txt` - Python dependencies
- `README.md` - This file

## 🔑 Environment Variables

The Lambda function expects these environment variables (set by Terraform):

- `MSK_BOOTSTRAP_SERVERS` - MSK cluster bootstrap servers
- `KAFKA_TOPIC` - Kafka topic name (default: "chargebacks")
- `AWS_REGION` - AWS region
- `LOG_LEVEL` - Logging level (default: "INFO")

## 📊 Monitoring

View logs in CloudWatch:

```bash
aws logs tail /aws/lambda/{function-name} --follow
```

## 🐛 Troubleshooting

### Error: "No module named 'kafka'"

Make sure you installed dependencies:
```bash
pip install -r requirements.txt -t .
```

### Error: "Connection refused to MSK"

Check security groups and VPC configuration in Terraform.

### Error: "Authentication failed"

Verify IAM role has kafka-cluster permissions.
