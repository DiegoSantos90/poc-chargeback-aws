# Phase 1: Foundation Infrastructure - Implementation Guide

## 📋 Overview

Phase 1 establishes the **foundational AWS infrastructure** required for the chargeback processing system. This phase creates the core networking, database, and storage components that will be used by subsequent phases.

## 🎯 Phase 1 Objectives

- ✅ **VPC with Public/Private Subnets**: Secure network isolation across multiple availability zones
- ✅ **NAT Gateways**: Enable private subnet internet access for updates and external APIs
- ✅ **VPC Endpoints**: Cost-efficient private connections to AWS services (S3, DynamoDB)
- ✅ **DynamoDB Table**: NoSQL database for chargeback records with streams enabled
- ✅ **S3 Buckets**: Storage for Parquet (optimized) and CSV (raw) data files
- ✅ **Security Groups**: Network access control for future compute resources

## 🏗️ Phase 1 Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                       AWS Region (sa-east-1)                   │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                     │ │
│  │                                                          │ │
│  │  ┌────────────────┐         ┌────────────────┐          │ │
│  │  │  AZ-a          │         │  AZ-b          │          │ │
│  │  │                │         │                │          │ │
│  │  │ ┌────────────┐ │         │ ┌────────────┐ │          │ │
│  │  │ │Public      │ │         │ │Public      │ │          │ │
│  │  │ │10.0.1.0/24 │ │         │ │10.0.2.0/24 │ │          │ │
│  │  │ │            │ │         │ │            │ │          │ │
│  │  │ │ NAT GW     │ │         │ │ NAT GW     │ │          │ │
│  │  │ └─────┬──────┘ │         │ └─────┬──────┘ │          │ │
│  │  │       │        │         │       │        │          │ │
│  │  │ ┌─────▼──────┐ │         │ ┌─────▼──────┐ │          │ │
│  │  │ │Private     │ │         │ │Private     │ │          │ │
│  │  │ │10.0.11.0/24│ │         │ │10.0.12.0/24│ │          │ │
│  │  │ │            │ │         │ │            │ │          │ │
│  │  │ │  Lambda    │ │         │ │  Lambda    │ │          │ │
│  │  │ │  (Phase 2) │ │         │ │  (Phase 2) │ │          │ │
│  │  │ └────────────┘ │         │ └────────────┘ │          │ │
│  │  └────────────────┘         └────────────────┘          │ │
│  │                                                          │ │
│  │  ┌──────────────────────────────────────────┐           │ │
│  │  │        VPC Endpoints (Private)           │           │ │
│  │  │  • S3 Gateway Endpoint                   │           │ │
│  │  │  • DynamoDB Gateway Endpoint             │           │ │
│  │  └──────────────────────────────────────────┘           │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              DynamoDB Table (Regional)                   │ │
│  │  • chargebacks table (PAY_PER_REQUEST)                   │ │
│  │  • Streams enabled (NEW_AND_OLD_IMAGES)                  │ │
│  │  • GSI: status-index                                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              S3 Buckets (Regional)                       │ │
│  │  • parquet-bucket (optimized data, versioned)            │ │
│  │  • csv-bucket (raw data, versioned)                      │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
infrastructure/terraform/phases/phase-1/
├── variables.tf              # Input variables and configuration
├── vpc.tf                    # VPC, subnets, IGW, NAT, routes
├── vpc-endpoints.tf          # S3 and DynamoDB VPC endpoints
├── security-groups.tf        # Security groups for DynamoDB access
├── dynamodb.tf               # DynamoDB table with streams
├── s3.tf                     # S3 buckets with versioning
└── outputs.tf                # Exported values for Phase 2+
```

## 🚀 Resources Created

### Networking (vpc.tf)
- **1x VPC** (10.0.0.0/16) with DNS support enabled
- **2x Public Subnets** (10.0.1.0/24, 10.0.2.0/24) - for NAT Gateways
- **2x Private Subnets** (10.0.11.0/24, 10.0.12.0/24) - for Lambda functions
- **1x Internet Gateway** - public subnet internet access
- **2x NAT Gateways** - private subnet outbound internet (HA setup)
- **2x Elastic IPs** - for NAT Gateways
- **3x Route Tables** - public and private routing

### VPC Endpoints (vpc-endpoints.tf)
- **S3 Gateway Endpoint** - Free, cost-efficient S3 access from VPC
- **DynamoDB Gateway Endpoint** - Free, private DynamoDB access

### Security (security-groups.tf)
- **DynamoDB Access Security Group** - controls DynamoDB table access

### Database (dynamodb.tf)
- **DynamoDB Table**: `poc-chargeback-chargebacks-dev`
  - **Billing Mode**: PAY_PER_REQUEST (on-demand)
  - **Partition Key**: `chargeback_id` (String)
  - **DynamoDB Streams**: Enabled (NEW_AND_OLD_IMAGES)
  - **Global Secondary Index**: `status-index` (for status queries)

### Storage (s3.tf)
- **Parquet Bucket**: `poc-chargeback-parquet-dev-{account-id}`
  - Versioning enabled
  - For optimized columnar data
- **CSV Bucket**: `poc-chargeback-csv-dev-{account-id}`
  - Versioning enabled
  - For raw/export data

## 📊 DynamoDB Table Schema

### Table: chargebacks

```json
{
  "chargeback_id": "cb_123456",           // Partition Key (String)
  "status": "pending",                    // GSI Hash Key (String)
  "merchant_id": "merch_789",             // String
  "amount": 150.00,                       // Number
  "currency": "USD",                      // String
  "created_at": "2025-10-19T10:30:00Z",   // String (ISO 8601)
  "updated_at": "2025-10-19T10:30:00Z",   // String (ISO 8601)
  "reason": "Product not received",       // String
  "metadata": {                           // Map
    "transaction_id": "txn_456",
    "customer_email": "customer@example.com"
  }
}
```

### Attributes
- **chargeback_id** (S): Primary partition key - unique identifier
- **status** (S): Used in GSI - values: pending, approved, rejected, processing

### Global Secondary Index: status-index
- **Hash Key**: status
- **Projection**: ALL (all attributes)
- **Use Case**: Query all chargebacks by status efficiently

### DynamoDB Streams
- **Stream View Type**: NEW_AND_OLD_IMAGES
- **Purpose**: Capture all item changes for event-driven processing
- **Used By**: Phase 3 Lambda stream processor

## 🔐 Security Features

### Network Isolation
- **Private subnets**: Lambda functions run in isolated private subnets
- **NAT Gateways**: Controlled outbound internet access only
- **No direct internet access**: Resources in private subnets can't be accessed from internet

### VPC Endpoints (PrivateLink)
- **S3 Gateway Endpoint**: Traffic to S3 never leaves AWS network
- **DynamoDB Gateway Endpoint**: Traffic to DynamoDB stays within VPC
- **Benefits**:
  - No data transfer charges
  - Reduced latency
  - Enhanced security (no internet exposure)

### Security Groups
- **Principle of least privilege**: Only necessary ports/protocols allowed
- **Stateful rules**: Return traffic automatically allowed
- **Fine-grained control**: Per-resource security policies

## 💰 Cost Optimization

### VPC Endpoints
- **Gateway Endpoints (S3, DynamoDB)**: **FREE** ✅
- **Saves**: Data transfer costs ($0.09/GB) for S3/DynamoDB traffic
- **Example**: 100GB/month → Save ~$9/month

### NAT Gateways
- **Cost**: $0.045/hour (~$32.40/month) + $0.045/GB processed
- **High Availability**: 2 NAT Gateways across AZs = ~$64.80/month
- **Optimization tip**: Consider single NAT Gateway for dev environments

### DynamoDB PAY_PER_REQUEST
- **No minimum cost**: Pay only for reads/writes
- **Dev friendly**: Ideal for development/testing
- **Production**: Consider provisioned capacity for predictable workloads

### S3 Versioning
- **Cost**: Each version stored separately (charged as separate object)
- **Optimization**: Configure lifecycle policies to delete old versions

## 🚀 Deployment Guide

### Prerequisites

1. **AWS CLI configured** with credentials and region
   ```bash
   aws configure
   # Region: sa-east-1
   ```

2. **Terraform installed** (version 1.0+)
   ```bash
   terraform version
   ```

3. **AWS Permissions** - IAM user/role needs:
   - VPC management (EC2)
   - DynamoDB table creation
   - S3 bucket creation
   - IAM role/policy creation (for future phases)

### Step 1: Initialize Terraform

```bash
cd infrastructure/terraform

# Download providers
terraform init
```

### Step 2: Review Variables

Edit `phases/phase-1/variables.tf` or create `terraform.tfvars`:

```hcl
# terraform.tfvars
project_name = "poc-chargeback"
environment  = "dev"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "sa-east-1a",
  "sa-east-1b"
]

tags = {
  Project   = "Chargeback POC"
  Team      = "Data Engineering"
  ManagedBy = "Terraform"
}
```

### Step 3: Plan Deployment

```bash
# Preview what will be created
terraform plan

# Review:
# - 25+ resources to create
# - VPC, Subnets, NAT Gateways
# - DynamoDB table
# - S3 buckets
```

### Step 4: Deploy Infrastructure

```bash
# Deploy Phase 1
terraform apply

# Type 'yes' to confirm
```

**Deployment time**: ~3-5 minutes

### Step 5: Verify Deployment

```bash
# Check VPC
terraform output vpc_id

# Check DynamoDB table
terraform output dynamodb_table_name

# Check S3 buckets
terraform output parquet_bucket_name
terraform output csv_bucket_name

# Test DynamoDB Stream
terraform output dynamodb_stream_arn
```

## 📤 Exported Outputs (for Phase 2+)

Phase 1 exports these values for use in subsequent phases:

### VPC Outputs
- `vpc_id` - VPC identifier
- `vpc_cidr` - VPC CIDR block
- `public_subnet_ids` - Public subnet IDs (list)
- `private_subnet_ids` - Private subnet IDs (list)
- `internet_gateway_id` - Internet Gateway ID
- `nat_gateway_ids` - NAT Gateway IDs (list)

### Security Groups
- `security_group_dynamodb_id` - DynamoDB access security group

### DynamoDB
- `dynamodb_table_name` - Table name for CRUD operations
- `dynamodb_table_arn` - Table ARN for IAM policies
- `dynamodb_stream_arn` - Stream ARN for event processing (Phase 3)

### S3
- `parquet_bucket_name` - Parquet bucket name
- `parquet_bucket_arn` - Parquet bucket ARN
- `csv_bucket_name` - CSV bucket name
- `csv_bucket_arn` - CSV bucket ARN

### VPC Endpoints
- `s3_vpc_endpoint_id` - S3 endpoint ID
- `dynamodb_vpc_endpoint_id` - DynamoDB endpoint ID

## 🔍 Testing Phase 1

### Test 1: VPC Connectivity

```bash
# Get VPC ID
VPC_ID=$(terraform output -raw vpc_id)

# Describe VPC
aws ec2 describe-vpcs --vpc-ids $VPC_ID --region sa-east-1

# Verify subnets exist
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region sa-east-1
```

### Test 2: DynamoDB Access

```bash
# Get table name
TABLE_NAME=$(terraform output -raw dynamodb_table_name)

# Describe table
aws dynamodb describe-table \
  --table-name $TABLE_NAME \
  --region sa-east-1

# Insert test item
aws dynamodb put-item \
  --table-name $TABLE_NAME \
  --item '{
    "chargeback_id": {"S": "test-001"},
    "status": {"S": "pending"},
    "amount": {"N": "100.50"},
    "currency": {"S": "USD"},
    "created_at": {"S": "2025-10-23T00:00:00Z"}
  }' \
  --region sa-east-1

# Query by partition key
aws dynamodb get-item \
  --table-name $TABLE_NAME \
  --key '{"chargeback_id": {"S": "test-001"}}' \
  --region sa-east-1

# Query by status (GSI)
aws dynamodb query \
  --table-name $TABLE_NAME \
  --index-name status-index \
  --key-condition-expression "#status = :status" \
  --expression-attribute-names '{"#status": "status"}' \
  --expression-attribute-values '{":status": {"S": "pending"}}' \
  --region sa-east-1
```

### Test 3: S3 Access

```bash
# Get bucket names
PARQUET_BUCKET=$(terraform output -raw parquet_bucket_name)
CSV_BUCKET=$(terraform output -raw csv_bucket_name)

# Upload test file
echo "test data" > test.txt

aws s3 cp test.txt s3://$PARQUET_BUCKET/test/test.txt --region sa-east-1

# List files
aws s3 ls s3://$PARQUET_BUCKET/test/ --region sa-east-1

# Download file
aws s3 cp s3://$PARQUET_BUCKET/test/test.txt downloaded.txt --region sa-east-1

# Verify versioning
aws s3api list-object-versions \
  --bucket $PARQUET_BUCKET \
  --prefix test/test.txt \
  --region sa-east-1

# Cleanup
aws s3 rm s3://$PARQUET_BUCKET/test/test.txt --region sa-east-1
rm test.txt downloaded.txt
```

### Test 4: VPC Endpoints

```bash
# Verify S3 endpoint
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=com.amazonaws.sa-east-1.s3" \
  --region sa-east-1

# Verify DynamoDB endpoint
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=service-name,Values=com.amazonaws.sa-east-1.dynamodb" \
  --region sa-east-1
```

## 🔧 Common Operations

### Update Infrastructure

```bash
# After modifying .tf files
terraform plan
terraform apply
```

### Destroy Infrastructure

```bash
# ⚠️  WARNING: This deletes ALL Phase 1 resources!
# DynamoDB tables, S3 buckets (if empty), VPC, etc.

terraform destroy

# Type 'yes' to confirm
```

**Note**: S3 buckets with `force_destroy = false` will prevent destruction if they contain objects.

### View Current State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show aws_vpc.main
terraform state show aws_dynamodb_table.chargebacks

# View all outputs
terraform output
```

## 📊 Monitoring

### CloudWatch Integration

Phase 1 resources automatically publish metrics to CloudWatch:

**DynamoDB Metrics** (Free):
- `ConsumedReadCapacityUnits`
- `ConsumedWriteCapacityUnits`
- `UserErrors`
- `SystemErrors`

**S3 Metrics** (Request Metrics - paid):
- `AllRequests`
- `GetRequests`
- `PutRequests`
- `BytesDownloaded`
- `BytesUploaded`

### View Metrics

```bash
# DynamoDB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=$TABLE_NAME \
  --start-time 2025-10-23T00:00:00Z \
  --end-time 2025-10-23T23:59:59Z \
  --period 3600 \
  --statistics Sum \
  --region sa-east-1
```

## 🐛 Troubleshooting

### Issue: Terraform Init Fails

```bash
# Solution: Clear cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Issue: NAT Gateway Creation Timeout

```bash
# NAT Gateways can take 3-5 minutes
# Wait and retry:
terraform apply
```

### Issue: S3 Bucket Name Already Exists

```bash
# S3 bucket names are globally unique
# Solution: Change project_name or environment in variables
```

### Issue: DynamoDB Streams Not Visible

```bash
# Streams take ~30 seconds after table creation
# Verify stream ARN:
aws dynamodb describe-table \
  --table-name $TABLE_NAME \
  --query 'Table.LatestStreamArn' \
  --region sa-east-1
```

### Issue: VPC Endpoint Not Working

```bash
# Verify route table association
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region sa-east-1

# Check endpoint status
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region sa-east-1
```

## 📚 Additional Resources

### AWS Documentation
- [Amazon VPC User Guide](https://docs.aws.amazon.com/vpc/)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/)
- [Amazon S3 User Guide](https://docs.aws.amazon.com/s3/)
- [VPC Endpoints Guide](https://docs.aws.amazon.com/vpc/latest/privatelink/)

### Terraform Documentation
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [VPC Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
- [DynamoDB Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table)
- [S3 Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)

## 🎯 Next Steps

After Phase 1 is deployed and tested, proceed to:

### Phase 2: API Gateway + Lambda
- REST API for chargeback CRUD operations
- Lambda function with Go runtime
- API Gateway integration
- CloudWatch monitoring

**See**: `PHASE2_README.md`

### Phase 3: Streaming Pipeline
- MSK Serverless (Kafka)
- Lambda stream processor (Python)
- Apache Flink for real-time processing
- Parquet file generation

**See**: `PHASE3_README.md`

---

## 📝 Summary

Phase 1 provides the **foundational infrastructure**:

✅ **Secure VPC** with public/private subnets across 2 AZs  
✅ **High-availability** NAT Gateways for internet access  
✅ **Cost-efficient** VPC endpoints for S3 and DynamoDB  
✅ **DynamoDB table** with streams for event-driven architecture  
✅ **S3 buckets** for data storage with versioning  
✅ **Exported outputs** ready for Phase 2 and Phase 3  

**Estimated Monthly Cost (dev environment)**:
- VPC & Networking: ~$65 (2 NAT Gateways)
- DynamoDB: ~$1-5 (pay-per-request, low usage)
- S3: ~$0.50-2 (depending on storage)
- **Total**: ~$66-72/month

**Cost optimization for dev**: Consider single NAT Gateway = ~$33/month savings

---

**Ready to proceed?** Deploy Phase 1, verify all resources, then move to Phase 2!
