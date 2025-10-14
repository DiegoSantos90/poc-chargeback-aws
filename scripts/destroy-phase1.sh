#!/bin/bash

# Safe destroy script for Phase 1 infrastructure
# Handles S3 buckets with versioning properly

set -e

echo "🗑️  Starting safe destroy of Phase 1 infrastructure..."

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

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "❌ Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

# Get bucket names before destroying
echo "📋 Getting S3 bucket names..."
PARQUET_BUCKET=$(terraform output -raw parquet_bucket_name 2>/dev/null || echo "")
CSV_BUCKET=$(terraform output -raw csv_bucket_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

if [ -n "$PARQUET_BUCKET" ] && [ -n "$CSV_BUCKET" ]; then
    echo "Found buckets to clean:"
    echo "  - Parquet: $PARQUET_BUCKET"
    echo "  - CSV: $CSV_BUCKET"
    echo ""
    
    # Optional: Clean buckets manually (safer for production)
    read -p "Do you want to empty the S3 buckets before destroy? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🧹 Emptying S3 buckets..."
        
        # Empty parquet bucket (including all versions)
        echo "Emptying $PARQUET_BUCKET..."
        aws s3api list-object-versions --bucket "$PARQUET_BUCKET" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output json --region "$AWS_REGION" | \
            jq -r '.[] | "--key " + .Key + " --version-id " + .VersionId' | \
            xargs -I {} aws s3api delete-object --bucket "$PARQUET_BUCKET" {} --region "$AWS_REGION" 2>/dev/null || true
        
        # Empty CSV bucket (including all versions)
        echo "Emptying $CSV_BUCKET..."
        aws s3api list-object-versions --bucket "$CSV_BUCKET" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output json --region "$AWS_REGION" | \
            jq -r '.[] | "--key " + .Key + " --version-id " + .VersionId' | \
            xargs -I {} aws s3api delete-object --bucket "$CSV_BUCKET" {} --region "$AWS_REGION" 2>/dev/null || true
        
        # Clean up delete markers
        aws s3api list-object-versions --bucket "$PARQUET_BUCKET" \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            --output json --region "$AWS_REGION" | \
            jq -r '.[] | "--key " + .Key + " --version-id " + .VersionId' | \
            xargs -I {} aws s3api delete-object --bucket "$PARQUET_BUCKET" {} --region "$AWS_REGION" 2>/dev/null || true
            
        aws s3api list-object-versions --bucket "$CSV_BUCKET" \
            --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
            --output json --region "$AWS_REGION" | \
            jq -r '.[] | "--key " + .Key + " --version-id " + .VersionId' | \
            xargs -I {} aws s3api delete-object --bucket "$CSV_BUCKET" {} --region "$AWS_REGION" 2>/dev/null || true
        
        echo "✅ Buckets emptied successfully"
    fi
fi

echo ""
echo "🚨 WARNING: This will destroy ALL infrastructure created in Phase 1!"
echo ""
echo "Resources to be destroyed:"
echo "  ✗ VPC and all subnets"
echo "  ✗ NAT Gateways and Elastic IPs (💰 billing will stop)"
echo "  ✗ DynamoDB table and all data"
echo "  ✗ S3 buckets and all contents"
echo "  ✗ VPC Endpoints"
echo "  ✗ Security Groups"
echo ""

read -p "Are you ABSOLUTELY sure you want to destroy everything? (yes/no): " -r
if [ "$REPLY" != "yes" ]; then
    echo "Destroy cancelled."
    exit 0
fi

echo ""
echo "🗑️  Running terraform destroy..."
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Infrastructure successfully destroyed!"
    echo ""
    echo "📊 What was destroyed:"
    echo "✅ VPC and networking components"
    echo "✅ DynamoDB table and streams" 
    echo "✅ S3 buckets and contents"
    echo "✅ NAT Gateways (billing stopped)"
    echo "✅ Elastic IPs (released)"
    echo ""
    echo "💰 Cost impact: NAT Gateway charges stopped (~$45/month per gateway)"
else
    echo ""
    echo "❌ Destroy failed!"
    echo ""
    echo "🔍 Common issues:"
    echo "1. S3 buckets not empty (run script again with bucket cleanup)"
    echo "2. VPC dependencies still exist" 
    echo "3. DynamoDB table has deletion protection enabled"
    echo ""
    echo "💡 Manual cleanup may be needed via AWS Console"
    exit 1
fi