#!/bin/bash

set -e

echo "==========================================="
echo "Testing Lambda Consolidation Updater"
echo "==========================================="

# Set environment variables
export DYNAMODB_TABLE_NAME="${DYNAMODB_TABLE_NAME:-poc-chargeback-chargebacks-dev}"
export AWS_REGION="${AWS_REGION:-sa-east-1}"
export LOG_LEVEL="DEBUG"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check Lambda deployment package exists
echo -e "\n${YELLOW}Test 1: Checking deployment package...${NC}"
if [ -f "../consolidation-updater.zip" ]; then
    echo -e "${GREEN}✓ Deployment package found${NC}"
    ls -lh ../consolidation-updater.zip
else
    echo -e "${RED}✗ Deployment package not found${NC}"
    echo "Run: cd deployments/lambda/consolidation-updater && ./build.sh"
    exit 1
fi

# Test 2: Check Lambda function exists in AWS
echo -e "\n${YELLOW}Test 2: Checking Lambda function in AWS...${NC}"
LAMBDA_NAME="poc-chargeback-dev-consolidation-updater"

if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${GREEN}✓ Lambda function exists${NC}"
    aws lambda get-function --function-name "$LAMBDA_NAME" --region "$AWS_REGION" \
        --query 'Configuration.{Name:FunctionName,Runtime:Runtime,Memory:MemorySize,Timeout:Timeout,State:State}' \
        --output table
else
    echo -e "${YELLOW}⚠ Lambda function not deployed yet${NC}"
    echo "Deploy with: cd infrastructure/terraform/phases/phase-4 && terraform apply"
fi

# Test 3: Check Event Source Mapping
echo -e "\n${YELLOW}Test 3: Checking MSK Event Source Mapping...${NC}"

MAPPINGS=$(aws lambda list-event-source-mappings \
    --function-name "$LAMBDA_NAME" \
    --region "$AWS_REGION" \
    --query 'EventSourceMappings[0].{UUID:UUID,State:State,Topics:Topics,BatchSize:BatchSize}' \
    --output json 2>/dev/null || echo "[]")

if [ "$MAPPINGS" != "[]" ] && [ "$MAPPINGS" != "null" ]; then
    echo -e "${GREEN}✓ Event source mapping configured${NC}"
    echo "$MAPPINGS" | jq .
else
    echo -e "${YELLOW}⚠ Event source mapping not configured yet${NC}"
fi

# Test 4: Check CloudWatch Log Group
echo -e "\n${YELLOW}Test 4: Checking CloudWatch Logs...${NC}"
LOG_GROUP="/aws/lambda/$LAMBDA_NAME"

if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$AWS_REGION" \
    --query "logGroups[?logGroupName=='$LOG_GROUP']" --output text | grep -q "$LOG_GROUP"; then
    echo -e "${GREEN}✓ Log group exists${NC}"
    
    # Show recent log streams
    echo -e "\nRecent log streams:"
    aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --region "$AWS_REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 5 \
        --query 'logStreams[*].logStreamName' \
        --output table
else
    echo -e "${YELLOW}⚠ Log group not found${NC}"
fi

# Test 5: Check DLQ
echo -e "\n${YELLOW}Test 5: Checking Dead Letter Queue...${NC}"
DLQ_NAME="poc-chargeback-dev-consolidation-dlq"

if aws sqs get-queue-url --queue-name "$DLQ_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${GREEN}✓ DLQ exists${NC}"
    
    # Check message count
    DLQ_URL=$(aws sqs get-queue-url --queue-name "$DLQ_NAME" --region "$AWS_REGION" --query 'QueueUrl' --output text)
    MSG_COUNT=$(aws sqs get-queue-attributes \
        --queue-url "$DLQ_URL" \
        --attribute-names ApproximateNumberOfMessages \
        --region "$AWS_REGION" \
        --query 'Attributes.ApproximateNumberOfMessages' \
        --output text)
    
    if [ "$MSG_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✓ DLQ is empty (no failures)${NC}"
    else
        echo -e "${RED}⚠ DLQ has $MSG_COUNT messages${NC}"
    fi
else
    echo -e "${YELLOW}⚠ DLQ not found${NC}"
fi

# Test 6: Trigger test invocation (if requested)
if [ "$1" == "--invoke" ]; then
    echo -e "\n${YELLOW}Test 6: Invoking Lambda with test event...${NC}"
    
    # Create test event
    cat > /tmp/test-event.json << 'EOF'
{
  "eventSource": "aws:kafka",
  "eventSourceArn": "arn:aws:kafka:sa-east-1:123456789012:cluster/test/abc-123",
  "records": {
    "chargeback-consolidation-events-0": [
      {
        "topic": "chargeback-consolidation-events",
        "partition": 0,
        "offset": 1,
        "timestamp": 1700000000000,
        "timestampType": "CREATE_TIME",
        "value": "eyJldmVudF90eXBlIjoiY29uc29saWRhdGlvbl9jb21wbGV0ZWQiLCJwYXJ0aXRpb25fZGF0ZSI6IjIwMjUtMTEtMjAiLCJleGVjdXRpb25fc2VxdWVuY2UiOjEsInRvdGFsX2V4ZWN1dGlvbnMiOjQsInJlY29yZHNfcHJvY2Vzc2VkIjoxMjUwMDAwLCJkdXBsaWNhdGVzX3JlbW92ZWQiOjEwLCJvdXRwdXRfZmlsZXMiOjEsIm91dHB1dF9mb3JtYXQiOiJjc3YiLCJvdXRwdXRfcGF0aCI6InMzOi8vYnVja2V0L2NvbnNvbGlkYXRlZC9jaGFyZ2ViYWNrcy95ZWFyPTIwMjUvbW9udGg9MTEvZGF5PTIwIiwiZXhlY3V0aW9uX3RpbWUiOiIyMDI1LTExLTIwVDA2OjMwOjAwIiwiY29tcGxldGVkX2F0IjoiMjAyNS0xMS0yMFQwNjo0NTozMi4xMjM0NTYrMDA6MDAiLCJqb2JfbmFtZSI6InBvYy1jaGFyZ2ViYWNrLWRldi1jaGFyZ2ViYWNrcy1jb25zb2xpZGF0aW9uIn0="
      }
    ]
  }
}
EOF
    
    echo "Test event value decoded:"
    echo '{"event_type":"consolidation_completed","partition_date":"2025-11-20","execution_sequence":1,"total_executions":4,"records_processed":1250000,"duplicates_removed":10,"output_files":1,"output_format":"csv","output_path":"s3://bucket/consolidated/chargebacks/year=2025/month=11/day=20","execution_time":"2025-11-20T06:30:00","completed_at":"2025-11-20T06:45:32.123456+00:00","job_name":"poc-chargeback-dev-chargebacks-consolidation"}' | jq .
    
    echo -e "\nInvoking Lambda..."
    aws lambda invoke \
        --function-name "$LAMBDA_NAME" \
        --payload file:///tmp/test-event.json \
        --region "$AWS_REGION" \
        /tmp/lambda-response.json
    
    echo -e "\nLambda response:"
    cat /tmp/lambda-response.json | jq .
    
    # Clean up
    rm /tmp/test-event.json /tmp/lambda-response.json
else
    echo -e "\n${YELLOW}Skipping test invocation (run with --invoke to test)${NC}"
fi

# Summary
echo -e "\n==========================================="
echo -e "${GREEN}Test Summary${NC}"
echo "==========================================="
echo "Lambda Function: $LAMBDA_NAME"
echo "Log Group: $LOG_GROUP"
echo "DLQ: $DLQ_NAME"
echo ""
echo "To tail logs:"
echo "  aws logs tail $LOG_GROUP --follow"
echo ""
echo "To invoke with test event:"
echo "  ./test.sh --invoke"
echo ""
echo "To check event source mapping:"
echo "  aws lambda list-event-source-mappings --function-name $LAMBDA_NAME"
echo "==========================================="
