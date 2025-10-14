# Scripts for Phase 1

This directory contains all utility scripts to manage Phase 1 infrastructure.

## 📜 Available Scripts

### 🚀 `deploy-phase1.sh`
**Function**: Complete Phase 1 infrastructure deployment

**Usage**:
```bash
# From project root directory
./scripts/deploy-phase1.sh

# Or from scripts directory
cd scripts
./deploy-phase1.sh
```

**What it does**:
- ✅ Checks AWS credentials
- ✅ Initializes Terraform if needed
- ✅ Validates configuration
- ✅ Shows deployment plan
- ✅ Calculates estimated costs
- ✅ Executes deployment with confirmation
- ✅ Shows summary of created resources

### 🧪 `validate-phase1.sh`
**Function**: Complete validation of deployed infrastructure

**Usage**:
```bash
# From project root directory
./scripts/validate-phase1.sh

# Or from scripts directory
cd scripts
./validate-phase1.sh
```

**What it tests**:
- ✅ VPC and subnets
- ✅ Internet Gateway and NAT Gateways
- ✅ DynamoDB (read/write)
- ✅ S3 buckets (upload/download)
- ✅ VPC Endpoints
- ✅ Security Groups

### 🗑️ `destroy-phase1.sh`
**Function**: Safe removal of all infrastructure

**Usage**:
```bash
# From project root directory
./scripts/destroy-phase1.sh

# Or from scripts directory
cd scripts
./destroy-phase1.sh
```

**What it does**:
- ✅ Identifies S3 buckets for cleanup
- ✅ Offers automatic bucket cleanup
- ✅ Removes all S3 object versions
- ✅ Confirms before destroying
- ✅ Executes destroy safely
- ✅ Confirms removed resources

## 🔧 Prerequisites

All scripts require:
- **AWS CLI** configured (`aws configure`)
- **Terraform** installed (>= 1.0)
- **jq** for JSON parsing (used by destroy script)

### jq Installation (if needed):

**macOS**:
```bash
brew install jq
```

**Linux (Ubuntu/Debian)**:
```bash
sudo apt-get install jq
```

**Linux (CentOS/RHEL)**:
```bash
sudo yum install jq
```

## 🎯 Recommended Workflow

### Initial Deploy:
```bash
# 1. Infrastructure deployment
./scripts/deploy-phase1.sh

# 2. Validation
./scripts/validate-phase1.sh
```

### Cleanup:
```bash
# Safe destroy (recommended)
./scripts/destroy-phase1.sh

# Or direct destroy (faster)
cd infrastructure/terraform
terraform destroy
```

## 🚨 Important Notes

1. **Costs**: NAT Gateways cost ~$45/month each (2 = $90/month)
2. **Security**: Scripts validate AWS credentials before executing
3. **Paths**: Scripts work from root directory or scripts/
4. **Logs**: All Terraform outputs are preserved
5. **State**: Terraform state stays in `infrastructure/terraform/`

## 🔍 Troubleshooting

### Error: "AWS CLI not configured"
```bash
aws configure
# Enter Access Key, Secret Key, Region, Output format
```

### Error: "jq command not found"
```bash
# Install jq following instructions above
```

### Error: "Terraform not found"
```bash
# Install Terraform: https://terraform.io/downloads
```

### Error: "Bucket already exists"
```bash
# Edit terraform.tfvars and change project_name
project_name = "poc-chargeback-unique-name"
```