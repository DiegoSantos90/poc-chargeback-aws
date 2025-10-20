# Phase 2: API Gateway + Lambda - Implementation Guide

## 📁 Project Structure

```
infrastructure/terraform/
├── main.tf                    # Main module orchestration
├── outputs.tf                 # Root outputs
├── variables.tf               # Root variables
├── providers.tf               # AWS provider config
│
└── phases/
    ├── phase-1/               # Foundation Infrastructure
    │   ├── variables.tf       # Phase 1 variables
    │   ├── vpc.tf            # VPC, Subnets, NAT, Routes
    │   ├── vpc-endpoints.tf  # S3 & DynamoDB endpoints
    │   ├── security-groups.tf # Security groups
    │   ├── dynamodb.tf       # Chargebacks table
    │   ├── s3.tf             # Parquet & CSV buckets
    │   └── outputs.tf        # Phase 1 outputs
    │
    └── phase-2/               # API Layer
        ├── variables.tf       # Phase 2 variables
        ├── data-sources.tf    # Import Phase 1 outputs
        ├── iam.tf            # Lambda execution role & policies
        ├── security-groups.tf # Lambda security group
        ├── lambda.tf         # Lambda function with versioning
        ├── api-gateway.tf    # REST API configuration
        ├── cloudwatch.tf     # Log groups
        └── outputs.tf        # Phase 2 outputs

deployments/lambda/
└── function.zip              # Lambda deployment package
```

## 🚀 Phase 2 Resources Created

- **Lambda Function**: Go custom runtime with versioning
- **Lambda Alias**: Points to specific version (enables rollback)
- **IAM Role**: Execution role with DynamoDB, S3, VPC, CloudWatch permissions
- **Security Group**: Lambda network access control
- **API Gateway REST API**: Regional endpoint
- **API Gateway Stage**: Dev stage with logging
- **CloudWatch Log Groups**: Lambda, API Gateway access & execution logs

## 📦 How to Build and Deploy Your Go API

### 1. Compile Go for Lambda

```bash
cd /path/to/your/go/api

# Compile for Linux AMD64
GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o bootstrap main.go

# Create deployment package
zip function.zip bootstrap

# Move to deployment directory
mv function.zip /path/to/poc-chargeback-aws/deployments/lambda/
```

### 2. Deploy Phase 2

```bash
cd infrastructure/terraform

# Initialize (if not done)
terraform init

# Review changes
terraform plan

# Deploy
terraform apply
```

### 3. Get API URL

```bash
terraform output api_gateway_url
```

## 🔄 Lambda Versioning & Rollback

### List Available Versions

```bash
aws lambda list-versions-by-function \
  --function-name poc-chargeback-api-handler-dev \
  --region sa-east-1
```

### Check Current Alias Version

```bash
aws lambda get-alias \
  --function-name poc-chargeback-api-handler-dev \
  --name dev \
  --region sa-east-1
```

### Rollback to Previous Version

```bash
aws lambda update-alias \
  --function-name poc-chargeback-api-handler-dev \
  --name dev \
  --function-version 5 \
  --region sa-east-1
```

**⚡ Rollback is instantaneous (< 1 second)!**

### Blue/Green Deployment (Optional)

Split traffic between versions (e.g., 90% v5, 10% v6):

```bash
aws lambda update-alias \
  --function-name poc-chargeback-api-handler-dev \
  --name dev \
  --function-version 6 \
  --routing-config AdditionalVersionWeights={"5"=0.9} \
  --region sa-east-1
```

## 🧪 Testing the API

### Health Check

```bash
export API_URL=$(terraform output -raw api_gateway_url)
curl $API_URL/health
```

### List Chargebacks

```bash
curl $API_URL/chargebacks
```

### Create Chargeback

```bash
curl -X POST $API_URL/chargebacks \
  -H "Content-Type: application/json" \
  -d '{
    "merchant_id": "merch_123",
    "amount": 150.00,
    "currency": "USD",
    "reason": "Product not received"
  }'
```

### Get Specific Chargeback

```bash
curl $API_URL/chargebacks/cb_123456
```

### Update Chargeback

```bash
curl -X PUT $API_URL/chargebacks/cb_123456 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "approved"
  }'
```

## 📊 Monitoring & Logs

### View Lambda Logs (Real-time)

```bash
aws logs tail $(terraform output -raw lambda_log_group_name) --follow
```

### View API Gateway Logs (Real-time)

```bash
aws logs tail $(terraform output -raw api_gateway_log_group_name) --follow
```

### CloudWatch Insights Queries

#### Find Errors

```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

#### Cold Starts

```
fields @timestamp, @initDuration
| filter ispresent(@initDuration)
| stats count() as coldStarts, avg(@initDuration) as avgColdStart
```

#### Top 10 IPs

```
fields ip
| stats count() as requestCount by ip
| sort requestCount desc
| limit 10
```

## 🔐 Security Features

- ✅ Lambda runs in **private subnets** (no public IP)
- ✅ DynamoDB & S3 access via **VPC Endpoints** (traffic stays in VPC)
- ✅ **Least privilege IAM policies** (resource-specific ARNs)
- ✅ **Security groups** control network access
- ✅ **Encrypted logs** in CloudWatch
- ✅ **Versioning** enabled (immutable deployments)

## 💰 Estimated Costs (POC)

- **Lambda**: ~$2-3/month (1M requests)
- **API Gateway**: ~$3.50/month (1M requests)
- **CloudWatch Logs**: ~$0.27/month (1 day retention)
- **NAT Gateway**: ~$32/month (Phase 1)
- **DynamoDB**: ~$1/month (on-demand)
- **S3**: ~$0.50/month

**Total Phase 2 Add-on**: ~$6/month
**Total Phase 1+2**: ~$40-45/month

## 📝 Environment Variables Available in Lambda

Your Go code can access these via `os.Getenv()`:

```go
AWS_REGION              = "sa-east-1"
DYNAMODB_TABLE_NAME     = "poc-chargeback-chargebacks-dev"
DYNAMODB_ENDPOINT       = "https://dynamodb.sa-east-1.amazonaws.com"
S3_PARQUET_BUCKET       = "poc-chargeback-parquet-dev-{account_id}"
S3_CSV_BUCKET           = "poc-chargeback-csv-dev-{account_id}"
S3_ENDPOINT             = "https://s3.sa-east-1.amazonaws.com"
ENVIRONMENT             = "dev"
LOG_LEVEL               = "DEBUG"  // DEBUG in dev, INFO in prod
ENABLE_METRICS          = "true"
ENABLE_TRACING          = "false"
```

## 🛠️ Troubleshooting

### Lambda Function Not Found

Ensure function.zip exists:
```bash
ls -lh deployments/lambda/function.zip
```

### VPC Endpoint Not Found

Ensure Phase 1 is deployed:
```bash
cd infrastructure/terraform
terraform output vpc_id
```

### Cold Start Latency

- First invocation: ~300-500ms (VPC ENI creation)
- Warm invocations: <100ms
- To keep warm: Use EventBridge schedule (optional)

### Permission Denied Errors

Check IAM role has correct policies:
```bash
terraform output lambda_role_arn
```

## 🎯 Next Steps

1. ✅ Phase 2 complete - API is deployed!
2. 🔄 Test all API endpoints
3. 📊 Monitor metrics in CloudWatch
4. 🔐 Add authentication (Cognito/API Keys)
5. 🚀 Implement CI/CD pipeline
6. 📈 Add more endpoints as needed

## 📚 Documentation

- [AWS Lambda Go](https://docs.aws.amazon.com/lambda/latest/dg/lambda-golang.html)
- [API Gateway Proxy Integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html)
- [Lambda Versioning](https://docs.aws.amazon.com/lambda/latest/dg/configuration-versions.html)
- [CloudWatch Logs Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html)

