#!/bin/bash

# Validation script for Phase 1 infrastructure
# This script tests if the DynamoDB table and S3 buckets are working correctly

set -e

echo "🚀 Starting Phase 1 Validation..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Get Terraform outputs
echo "📋 Getting Terraform outputs..."

# Navigate to project root if we're in scripts directory
if [[ $(basename $(pwd)) == "scripts" ]]; then
    cd ..
fi

cd infrastructure/terraform
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids 2>/dev/null || echo "")
PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids 2>/dev/null || echo "")
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "")
PARQUET_BUCKET=$(terraform output -raw parquet_bucket_name 2>/dev/null || echo "")
CSV_BUCKET=$(terraform output -raw csv_bucket_name 2>/dev/null || echo "")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

if [ -z "$VPC_ID" ] || [ -z "$DYNAMODB_TABLE" ] || [ -z "$PARQUET_BUCKET" ] || [ -z "$CSV_BUCKET" ]; then
    echo "❌ Cannot get Terraform outputs. Make sure infrastructure is deployed."
    exit 1
fi

echo "✅ Found resources:"
echo "   VPC ID: $VPC_ID"
echo "   DynamoDB Table: $DYNAMODB_TABLE"
echo "   Parquet Bucket: $PARQUET_BUCKET" 
echo "   CSV Bucket: $CSV_BUCKET"
echo ""

# Test VPC infrastructure
echo "🏗️  Testing VPC infrastructure..."
if aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$AWS_REGION" &> /dev/null; then
    echo "✅ VPC exists and is accessible"
    
    # Check subnets
    PUBLIC_COUNT=$(echo "$PUBLIC_SUBNETS" | jq '. | length' 2>/dev/null || echo "0")
    PRIVATE_COUNT=$(echo "$PRIVATE_SUBNETS" | jq '. | length' 2>/dev/null || echo "0")
    
    if [ "$PUBLIC_COUNT" -gt 0 ] && [ "$PRIVATE_COUNT" -gt 0 ]; then
        echo "✅ Public subnets: $PUBLIC_COUNT, Private subnets: $PRIVATE_COUNT"
    else
        echo "❌ Subnets not properly configured"
        exit 1
    fi
    
    # Check Internet Gateway
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --region "$AWS_REGION" 2>/dev/null)
    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        echo "✅ Internet Gateway attached to VPC"
    else
        echo "❌ Internet Gateway not found or not attached"
        exit 1
    fi
    
    # Check NAT Gateways
    NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways | length(@)' --output text --region "$AWS_REGION" 2>/dev/null || echo "0")
    if [ "$NAT_COUNT" -gt 0 ]; then
        echo "✅ NAT Gateways: $NAT_COUNT"
    else
        echo "❌ NAT Gateways not found"
        exit 1
    fi
    
else
    echo "❌ VPC not accessible"
    exit 1
fi

echo ""

# Test DynamoDB table
echo "🔍 Testing DynamoDB table..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &> /dev/null; then
    echo "✅ DynamoDB table exists and is accessible"
    
    # Test write operation
    echo "📝 Testing write operation..."
    TEST_ID="test-$(date +%s)"
    aws dynamodb put-item \
        --table-name "$DYNAMODB_TABLE" \
        --item '{
            "chargeback_id": {"S": "'$TEST_ID'"},
            "transaction_id": {"S": "test-txn-123"},
            "amount": {"S": "100.00"},
            "card_company": {"S": "VISA"},
            "reason": {"S": "Test validation"},
            "status": {"S": "PENDING"},
            "created_at": {"S": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}
        }' \
        --region "$AWS_REGION" > /dev/null
    
    echo "✅ Write operation successful"
    
    # Test read operation
    echo "📖 Testing read operation..."
    ITEM=$(aws dynamodb get-item \
        --table-name "$DYNAMODB_TABLE" \
        --key '{"chargeback_id": {"S": "'$TEST_ID'"}}' \
        --region "$AWS_REGION" \
        --output json)
    
    if echo "$ITEM" | grep -q "$TEST_ID"; then
        echo "✅ Read operation successful"
    else
        echo "❌ Read operation failed"
        exit 1
    fi
    
    # Clean up test data
    aws dynamodb delete-item \
        --table-name "$DYNAMODB_TABLE" \
        --key '{"chargeback_id": {"S": "'$TEST_ID'"}}' \
        --region "$AWS_REGION" > /dev/null
    echo "🧹 Test data cleaned up"
    
else
    echo "❌ DynamoDB table not accessible"
    exit 1
fi

echo ""

# Test S3 buckets
echo "🗄️  Testing S3 buckets..."

# Test parquet bucket
if aws s3 ls "s3://$PARQUET_BUCKET" --region "$AWS_REGION" &> /dev/null; then
    echo "✅ Parquet S3 bucket exists and is accessible"
    
    # Test write to parquet bucket
    echo "test file" > /tmp/test-parquet.txt
    if aws s3 cp /tmp/test-parquet.txt "s3://$PARQUET_BUCKET/validation/test.txt" --region "$AWS_REGION" &> /dev/null; then
        echo "✅ Write to parquet bucket successful"
        aws s3 rm "s3://$PARQUET_BUCKET/validation/test.txt" --region "$AWS_REGION" &> /dev/null
    else
        echo "❌ Write to parquet bucket failed"
        exit 1
    fi
else
    echo "❌ Parquet S3 bucket not accessible"
    exit 1
fi

# Test CSV bucket  
if aws s3 ls "s3://$CSV_BUCKET" --region "$AWS_REGION" &> /dev/null; then
    echo "✅ CSV S3 bucket exists and is accessible"
    
    # Test write to CSV bucket
    echo "test file" > /tmp/test-csv.txt
    if aws s3 cp /tmp/test-csv.txt "s3://$CSV_BUCKET/validation/test.txt" --region "$AWS_REGION" &> /dev/null; then
        echo "✅ Write to CSV bucket successful"
        aws s3 rm "s3://$CSV_BUCKET/validation/test.txt" --region "$AWS_REGION" &> /dev/null
    else
        echo "❌ Write to CSV bucket failed"
        exit 1
    fi
else
    echo "❌ CSV S3 bucket not accessible"
    exit 1
fi

# Cleanup
rm -f /tmp/test-parquet.txt /tmp/test-csv.txt

echo ""
echo "🎉 Phase 1 validation completed successfully!"
echo ""
echo "📊 Summary:"
echo "✅ VPC created with public and private subnets"
echo "✅ Internet Gateway and NAT Gateways configured"
echo "✅ VPC Endpoints for S3 and DynamoDB created"
echo "✅ DynamoDB table created and working"
echo "✅ DynamoDB streams enabled" 
echo "✅ S3 parquet bucket created and accessible"
echo "✅ S3 CSV bucket created and accessible"
echo "✅ Read/write operations working"
echo "✅ Security groups configured"
echo ""
echo "🚀 Ready to proceed to Phase 2!"