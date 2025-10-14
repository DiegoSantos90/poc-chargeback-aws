#!/bin/bash

# Deploy script for Phase 1 infrastructure
# Handles initialization, planning, and deployment with safety checks

set -e

echo "🚀 Starting Phase 1 deployment..."

# Navigate to terraform directory
echo "📂 Navigating to terraform directory..."

# Check if we're in scripts directory and navigate up
if [[ $(basename $(pwd)) == "scripts" ]]; then
    cd ../infrastructure/terraform
elif [ -d "infrastructure/terraform" ]; then
    cd infrastructure/terraform
elif [ -f "main.tf" ]; then
    # Already in terraform directory
    echo "Already in terraform directory"
else
    echo "❌ Cannot find terraform directory."
    echo "Please run from project root or infrastructure/terraform directory"
    exit 1
fi

# Check if AWS CLI is configured
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

echo "✅ AWS credentials configured:"
aws sts get-caller-identity --query 'Account' --output text | sed 's/^/   Account: /'
aws sts get-caller-identity --query 'Arn' --output text | sed 's/^/   User: /'

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo ""
    echo "🔧 Initializing Terraform..."
    terraform init
else
    echo "✅ Terraform already initialized"
fi

# Validate configuration
echo ""
echo "✅ Validating Terraform configuration..."
terraform validate
if [ $? -ne 0 ]; then
    echo "❌ Terraform configuration is invalid"
    exit 1
fi

# Show what will be created
echo ""
echo "📋 Planning deployment..."
terraform plan -out=tfplan

if [ $? -ne 0 ]; then
    echo "❌ Terraform plan failed"
    exit 1
fi

echo ""
echo "📊 Summary of changes:"
terraform show -json tfplan | jq -r '.planned_values.root_module.resources[] | select(.type) | .type' | sort | uniq -c | sort -nr

echo ""
echo "💰 Estimated monthly costs:"
echo "   • NAT Gateways: ~$90/month (2 gateways × $45 each)"
echo "   • DynamoDB: Pay-per-request (minimal for testing)"
echo "   • S3: Pay-per-use (minimal for testing)"
echo "   • VPC/Subnets: Free"
echo ""
echo "🏷️  Resources will be tagged with:"
echo "   • Environment: dev"
echo "   • Phase: 1"
echo "   • Project: poc-chargeback"

echo ""
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

# Apply the plan
echo ""
echo "🚀 Deploying infrastructure..."
terraform apply tfplan

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Phase 1 deployment completed successfully!"
    echo ""
    echo "📋 Created resources:"
    terraform show -json | jq -r '.values.root_module.child_modules[].resources[] | select(.values.tags.Phase == "1") | "✅ \(.type): \(.values.tags.Name // .address)"'
    
    echo ""
    echo "🔍 Key outputs:"
    echo "VPC ID: $(terraform output -raw vpc_id)"
    echo "DynamoDB Table: $(terraform output -raw dynamodb_table_name)"
    echo "Parquet Bucket: $(terraform output -raw parquet_bucket_name)"
    echo "CSV Bucket: $(terraform output -raw csv_bucket_name)"
    
    echo ""
    echo "🧪 Next steps:"
    echo "1. Run validation: cd ../../ && ./scripts/validate-phase1.sh"
    echo "2. Test the infrastructure"
    echo "3. Proceed to Phase 2 when ready"
    
    # Clean up plan file
    rm -f tfplan
    
else
    echo ""
    echo "❌ Deployment failed!"
    echo ""
    echo "🔍 Common issues:"
    echo "1. AWS permissions insufficient"
    echo "2. Resource limits exceeded"
    echo "3. S3 bucket names already taken (try changing project_name)"
    echo "4. Availability zones don't exist in selected region"
    echo ""
    echo "💡 Check the error messages above and fix the issues"
    
    # Clean up plan file
    rm -f tfplan
    exit 1
fi