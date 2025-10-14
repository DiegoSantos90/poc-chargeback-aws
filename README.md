# POC Chargeback AWS - Phase 1: Foundation

## 📋 Overview

This project implements a chargeback system on AWS. **This documentation focuses exclusively on Phase 1** - the infrastructure foundation.

## 🎯 Phase 1 Objectives

Phase 1 establishes the network, data, and storage foundation of the system:

- ✅ **VPC**: Private network with public and private subnets
- ✅ **Internet Gateway + NAT Gateways**: Secure internet connectivity
- ✅ **VPC Endpoints**: Optimized access to S3 and DynamoDB
- ✅ **DynamoDB**: Main table for storing chargebacks
- ✅ **DynamoDB Streams**: Enabled to capture changes (used in future phases)
- ✅ **S3 Buckets**: Storage for parquet and CSV files
- ✅ **Security Groups**: Security groups for access control
- ✅ **Validation**: Scripts to test that everything is working

## 🏗️ Phase 1 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                           VPC (10.0.0.0/16)                │
│                                                             │
│  ┌─────────────────┐              ┌─────────────────┐      │
│  │ Public Subnets  │              │ Private Subnets │      │
│  │                 │              │                 │      │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │      │
│  │ │Internet     │ │              │ │NAT Gateways │ │      │
│  │ │Gateway      │ │              │ │             │ │      │
│  │ └─────────────┘ │              │ └─────────────┘ │      │
│  └─────────────────┘              └─────────────────┘      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                VPC Endpoints                        │   │
│  │  ┌─────────────┐          ┌─────────────┐          │   │
│  │  │     S3      │          │  DynamoDB   │          │   │
│  │  │  Endpoint   │          │  Endpoint   │          │   │
│  │  └─────────────┘          └─────────────┘          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DynamoDB      │    │   S3 Buckets    │    │ Security Groups │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Chargebacks │ │    │ │ Parquet     │ │    │ │ DynamoDB    │ │
│ │   Table     │ │    │ │ Files       │ │    │ │ Access      │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │                 │
│ │ DynamoDB    │ │    │ │ CSV Files   │ │    │                 │
│ │ Streams     │ │    │ │             │ │    │                 │
│ └─────────────┘ │    │ └─────────────┘ │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
poc-chargeback-aws/
├── infrastructure/
│   └── terraform/
│       ├── main.tf              # Main configuration
│       ├── variables.tf         # Project variables  
│       ├── providers.tf         # AWS configuration
│       ├── outputs.tf           # Terraform outputs
│       ├── terraform.tfvars.example  # Configuration example
│       └── phases/
│           └── main.tf          # Phase 1 infrastructure
├── scripts/
│   ├── deploy-phase1.sh         # Deployment script
│   ├── validate-phase1.sh       # Validation script
│   ├── destroy-phase1.sh        # Safe removal script
│   └── README.md                # Scripts documentation
├── docs/
└── README.md
```

## 🚀 How to Implement

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** installed (version >= 1.0)
3. AWS permissions to create:
   - DynamoDB tables
   - S3 buckets
   - IAM roles (future phases)

### Step 1: Configure Variables

Edit the `infrastructure/terraform/variables.tf` file if necessary:

```hcl
variable "project_name" {
  default = "poc-chargeback"  # Change if desired
}

variable "environment" {
  default = "dev"             # dev, staging, prod
}

variable "aws_region" {
  default = "us-east-1"       # Your preferred region
}
```

### Step 2: Deploy Infrastructure

**Option 1: Automated Script (Recommended)**
```bash
# Complete deployment with validations
./scripts/deploy-phase1.sh
```

**Option 2: Manual Terraform**
```bash
# Navigate to Terraform directory
cd infrastructure/terraform

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Apply changes
terraform apply
```

### Step 3: Validate Implementation

```bash
# Run validation script
./scripts/validate-phase1.sh
```

## 📊 Created Resources

After successful execution, the following resources will be available:

### VPC (Virtual Private Cloud)

- **CIDR**: `10.0.0.0/16` (configurable)
- **Public Subnets**: 2 subnets in different AZs
- **Private Subnets**: 2 subnets in different AZs
- **Internet Gateway**: For public subnets internet access
- **NAT Gateways**: 2 gateways for private subnets internet access
- **VPC Endpoints**: S3 and DynamoDB to reduce costs and improve performance

### Security Groups

- **DynamoDB Access**: Allows HTTPS access on port 443 within the VPC

### DynamoDB Table: `chargebacks`

- **Hash Key**: `chargeback_id` (String)
- **GSI**: `status-index` for status queries
- **Streams**: Enabled (NEW_AND_OLD_IMAGES)
- **Billing**: Pay per request
- **Access**: Through VPC Endpoint (no internet)

### S3 Buckets

1. **Parquet Bucket**: `poc-chargeback-parquet-files-dev`
   - Versioning enabled
   - For parquet files (used in next phases)
   - Access via VPC Endpoint

2. **CSV Bucket**: `poc-chargeback-csv-files-dev`  
   - Versioning enabled
   - For final CSV files
   - Access via VPC Endpoint

## 🔍 Validation and Testing

The `validate-phase1.sh` script executes the following tests:

1. ✅ Verifies VPC was created correctly
2. ✅ Validates public and private subnets
3. ✅ Confirms Internet Gateway and NAT Gateways
4. ✅ Verifies DynamoDB table exists
5. ✅ Tests write/read operations on the table
6. ✅ Verifies S3 buckets exist and are accessible
7. ✅ Tests file upload/download on buckets
8. ✅ Automatically cleans up test data

## 📈 Monitoring

To monitor Phase 1 resources:

```bash
# View VPC information
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# View subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# View DynamoDB table information
aws dynamodb describe-table --table-name chargebacks

# List objects in S3 buckets
aws s3 ls s3://poc-chargeback-parquet-files-dev/
aws s3 ls s3://poc-chargeback-csv-files-dev/

# View VPC Endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# View CloudWatch metrics
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name ConsumedReadCapacityUnits
```

## 🔧 Troubleshooting

### Error: "Table already exists"
```bash
# Import existing table to Terraform state
terraform import module.phase1.aws_dynamodb_table.chargebacks chargebacks
```

### Error: "Bucket already exists"
```bash  
# Check if bucket exists in another region/account
aws s3api head-bucket --bucket poc-chargeback-parquet-files-dev
```

### Error: "Access Denied"
```bash
# Check AWS permissions
aws sts get-caller-identity
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
```

## 🗑️ Cleanup

### Option 1: Safe Destroy (Recommended)

```bash
./scripts/destroy-phase1.sh
```

The safe destroy script:
- ✅ Checks if there are objects in S3 buckets
- ✅ Offers option to clean buckets automatically
- ✅ Confirms before destroying
- ✅ Removes all S3 object versions

### Option 2: Direct Destroy (Fast)

```bash
cd infrastructure/terraform
terraform destroy
```

⚠️ **Warning**: 
- This will permanently remove all data!
- May fail if there are objects in S3 buckets
- For DEV environment, `force_destroy=true` is automatically enabled

## 🚀 Next Steps

After successfully validating Phase 1, you'll be ready for:

1. **Phase 2**: API Gateway + Lambda for data ingestion
2. **Phase 3**: Kinesis Data Analytics for streaming processing  
3. **Phase 4**: AWS Glue for batch processing
4. **Phase 5**: EventBridge + Notifications

## 📞 Support

For questions about Phase 1:

1. Check Terraform logs: `terraform show`
2. Run validation script: `./validation/validate-phase1.sh`
3. Consult AWS documentation for DynamoDB and S3
