# Lambda Stream Processor README

## 📦 How to Build and Deploy

### Option 1: Automated Build (Recommended) ✨

Use the build script that handles everything automatically:

```bash
cd deployments/lambda/stream-processor
./build.sh
```

**What it does:**
- ✅ Installs Python dependencies
- ✅ Creates deployment package (zip)
- ✅ Cleans up temporary files automatically
- ✅ Shows package size and next steps

### Option 2: Manual Build

If you prefer to build manually:

```bash
cd deployments/lambda/stream-processor

# Install dependencies
pip install -r requirements.txt -t .

# Create deployment package
zip -r ../stream-processor.zip .

# Clean up temporary files
rm -rf kafka/ boto3/ botocore/ aws_msk_iam_sasl_signer/ \
       dateutil/ urllib3/ s3transfer/ jmespath/ click/ \
       *.dist-info/ six.py __pycache__/ bin/
```

### Deploy via Terraform

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
