# Consolidation Updater Lambda Function

## Overview

This Lambda function consumes consolidation events from the MSK Kafka topic `chargeback-consolidation-events` and updates DynamoDB chargeback records with consolidation metadata.

**Architecture Position**:
```
AWS Glue Job → Kafka (consolidation-events) → Lambda → DynamoDB
```

## Features

- ✅ **MSK Event Source**: Triggered by Kafka messages
- ✅ **Batch Processing**: Handles up to 100 messages per invocation
- ✅ **Partial Batch Failures**: Returns failed messages for automatic retry
- ✅ **Idempotent Updates**: Safe to retry without duplicates
- ✅ **CloudWatch Metrics**: Custom metrics for monitoring
- ✅ **Structured Logging**: JSON logs with correlation IDs
- ✅ **Error Handling**: DLQ for poison messages

## Event Schema

### Input: Kafka Message (from Glue Job)

```json
{
  "event_type": "consolidation_completed",
  "partition_date": "2025-11-20",
  "execution_sequence": 2,
  "total_executions": 4,
  "records_processed": 1250000,
  "duplicates_removed": 150,
  "output_files": 10,
  "output_format": "csv",
  "output_path": "s3://bucket/consolidated/chargebacks/year=2025/month=11/day=20",
  "execution_time": "2025-11-20T06:30:00",
  "completed_at": "2025-11-20T06:45:32.123456+00:00",
  "job_name": "poc-chargeback-dev-chargebacks-consolidation"
}
```

### Output: DynamoDB Update

Updates chargeback records with these attributes:
- `consolidation_status`: "completed"
- `consolidation_s3_path`: S3 URI to consolidated files
- `consolidation_date`: ISO timestamp
- `consolidation_execution`: Execution sequence number
- `consolidation_job_name`: Glue job name
- `output_format`: "csv", "parquet", or "json"
- `records_in_consolidation`: Total records count
- `updated_at`: Update timestamp

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DYNAMODB_TABLE_NAME` | `poc-chargeback-chargebacks-dev` | DynamoDB table name |
| `AWS_REGION` | `sa-east-1` | AWS region |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARN, ERROR) |

## Local Testing

### Prerequisites

- Python 3.11+
- AWS credentials configured
- Access to DynamoDB table

### Run Tests

```bash
# Set environment variables
export DYNAMODB_TABLE_NAME=poc-chargeback-chargebacks-dev
export AWS_REGION=sa-east-1
export LOG_LEVEL=DEBUG

# Install dependencies
pip install -r requirements.txt

# Run with sample event
python lambda_function.py
```

### Sample Test Event

Create `test_event.json`:

```json
{
  "eventSource": "aws:kafka",
  "eventSourceArn": "arn:aws:kafka:sa-east-1:123456:cluster/test",
  "records": {
    "chargeback-consolidation-events-0": [
      {
        "topic": "chargeback-consolidation-events",
        "partition": 0,
        "offset": 123,
        "timestamp": 1700639732123,
        "timestampType": "CREATE_TIME",
        "key": "",
        "value": "eyJldmVudF90eXBlIjoiY29uc29saWRhdGlvbl9jb21wbGV0ZWQiLCJwYXJ0aXRpb25fZGF0ZSI6IjIwMjUtMTEtMjAiLCJleGVjdXRpb25fc2VxdWVuY2UiOjIsInRvdGFsX2V4ZWN1dGlvbnMiOjQsInJlY29yZHNfcHJvY2Vzc2VkIjoxMjUwMDAwLCJkdXBsaWNhdGVzX3JlbW92ZWQiOjE1MCwib3V0cHV0X2ZpbGVzIjoxMCwib3V0cHV0X2Zvcm1hdCI6ImNzdiIsIm91dHB1dF9wYXRoIjoiczM6Ly9idWNrZXQvY29uc29saWRhdGVkL2NoYXJnZWJhY2tzL3llYXI9MjAyNS9tb250aD0xMS9kYXk9MjAiLCJleGVjdXRpb25fdGltZSI6IjIwMjUtMTEtMjBUMDY6MzA6MDAiLCJjb21wbGV0ZWRfYXQiOiIyMDI1LTExLTIwVDA2OjQ1OjMyLjEyMzQ1NiswMDowMCIsImpvYl9uYW1lIjoicG9jLWNoYXJnZWJhY2stZGV2LWNoYXJnZWJhY2tzLWNvbnNvbGlkYXRpb24ifQ==",
        "headers": []
      }
    ]
  }
}
```

## Building for Deployment

```bash
# Make build script executable
chmod +x build.sh

# Run build
./build.sh

# Output: consolidation-updater.zip
```

## Deployment

The Lambda function is deployed via Terraform:

```bash
cd infrastructure/terraform/phases/phase-4

# Deploy
terraform apply
```

## Monitoring

### CloudWatch Logs

```bash
# Tail logs
aws logs tail /aws/lambda/poc-chargeback-dev-consolidation-updater --follow

# Filter errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/poc-chargeback-dev-consolidation-updater \
  --filter-pattern "ERROR"
```

### CloudWatch Metrics

Custom metrics published to namespace `POC-Chargeback/ConsolidationUpdater`:

- `MessagesProcessed`: Successfully processed messages
- `MessagesFailed`: Failed messages
- `ChargebacksUpdated`: Total DynamoDB updates

### CloudWatch Insights Queries

**Processing Summary**:
```
fields @timestamp, @message
| filter @message like /METRICS:/
| parse @message "messages_processed=*, messages_failed=*, chargebacks_updated=*" 
    as processed, failed, updated
| stats sum(processed) as total_processed, 
        sum(failed) as total_failed, 
        sum(updated) as total_updated by bin(1h)
```

**Error Analysis**:
```
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(1h)
```

## Troubleshooting

### Lambda Not Invoking

**Check event source mapping**:
```bash
aws lambda list-event-source-mappings \
  --function-name poc-chargeback-dev-consolidation-updater
```

**Verify mapping is enabled**:
```bash
aws lambda get-event-source-mapping \
  --uuid <mapping-uuid>
```

### DynamoDB Update Failures

**Check IAM permissions**:
- Ensure Lambda role has `dynamodb:UpdateItem` permission
- Verify resource ARN matches table

**Check table schema**:
- Verify `chargeback_id` partition key exists
- Check that `created_at` field is populated

### High Error Rate

**Check DLQ**:
```bash
aws sqs get-queue-attributes \
  --queue-url <dlq-url> \
  --attribute-names ApproximateNumberOfMessages
```

**Redrive from DLQ**:
```bash
# Process DLQ messages manually or configure Lambda to consume DLQ
```

## Performance

- **Cold Start**: ~500ms (VPC attached)
- **Warm Execution**: ~100-500ms (depends on batch size)
- **Throughput**: 100 messages per invocation
- **Concurrency**: Auto-scaled by Lambda

## Cost Estimate

- **Invocations**: 120/month (4 per day)
- **Duration**: ~2 seconds per invocation
- **Memory**: 256 MB
- **Monthly Cost**: ~$0.06

## Security

- ✅ Runs in VPC private subnets
- ✅ IAM authentication for MSK
- ✅ Least-privilege IAM policies
- ✅ Encrypted logs in CloudWatch
- ✅ No hardcoded credentials

## Future Enhancements

- [ ] Add unit tests with pytest
- [ ] Implement DynamoDB batch writes for better performance
- [ ] Add SNS notifications for failures
- [ ] Implement exponential backoff for retries
- [ ] Add X-Ray tracing for distributed debugging
