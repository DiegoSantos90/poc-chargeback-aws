# Testing Strategy - Cost-Effective POC Validation

## 🎯 Objective

Test the complete chargeback data pipeline with **minimal AWS costs** (target: < $10-20 total).

## 💰 Cost Breakdown & Optimization

### Expected Costs for POC Testing

| Service | Free Tier | POC Usage | Estimated Cost |
|---------|-----------|-----------|----------------|
| **VPC** | None | VPC + 3 AZs + Subnets | **$0.00** (no data transfer) |
| **NAT Gateway** | None | 10 min × 3 AZs | **$0.22** ⚠️ |
| **VPC Endpoints** | None | S3 + DynamoDB | **$0.07** (1 hour) |
| **S3** | 5 GB storage, 20K requests | 50 MB data | **$0.00** (free tier) |
| **DynamoDB** | 25 GB, 25 RCU/WCU | 1,000 test records | **$0.00** (free tier) |
| **DynamoDB Streams** | Included | 1,000 events | **$0.00** |
| **Lambda** | 1M requests, 400K GB-sec | ~5K invocations | **$0.00** (free tier) |
| **MSK Serverless** | None | 1 hour active | **$0.75** ⚠️ |
| **Kinesis Flink** | None | 1 KPU × 1 hour | **$0.11** |
| **Glue Crawler** | None | 2 runs × 3 min | **$0.04** |
| **Glue ETL Job** | None | 2 workers × 10 min | **$0.29** |
| **CloudWatch Logs** | 5 GB ingestion | 100 MB logs | **$0.00** (free tier) |
| | | **SUBTOTAL** | **~$1.48** |
| | | **+ Terraform overhead** | **~$0.10** |
| | | **REALISTIC TOTAL** | **~$1.60-$2.00** |

### 🔑 Key Cost-Saving Strategies

1. **NAT Gateway is expensive** ($0.045/hour × 3 AZs = $0.135/hour)
   - Deploy quickly, destroy immediately
   - Even 10 minutes costs ~$0.22!
   
2. **Use VPC Endpoints** for S3/DynamoDB (cheaper than NAT)
   - $0.01/hour vs NAT's $0.045/hour
   
3. **Test with small datasets** (100-1,000 records, not 5M)

4. **Run services for minimal time**
   - MSK: 1 hour max ($0.75)
   - Flink: 1 hour max ($0.11)
   - Glue: Quick runs only
   
5. **Destroy resources IMMEDIATELY after each phase**
   - Don't leave Phase 1 running while testing Phase 2
   
6. **Disable automatic scaling** and use minimum resources
   - Glue: 2 workers (not 10)
   - Flink: 1 KPU (not auto-scaling)

---

## ⚠️ CRITICAL: NAT Gateway Costs

### The Hidden Cost Killer

**NAT Gateway pricing:**
- $0.045/hour per NAT Gateway
- Phase 1 creates **3 NAT Gateways** (one per AZ)
- **Total: $0.135/hour = $97.20/month if left running!**

### Cost Examples:
| Duration | Cost |
|----------|------|
| 10 minutes | $0.22 |
| 1 hour | $1.35 |
| 8 hours (workday) | $10.80 |
| 24 hours | $32.40 |
| 1 month | $97.20 |

### 💡 Cost-Saving Alternative: VPC Endpoints

Instead of NAT Gateways, use VPC Endpoints for S3 and DynamoDB:

```bash
# Add to Phase 1 terraform variables:
enable_nat_gateway = false  # Disable NAT Gateways
enable_vpc_endpoints = true # Enable VPC Endpoints instead

# Cost comparison:
# NAT: $0.135/hour ($97/month)
# VPC Endpoints: $0.01/hour ($7/month)
# Savings: 93% cheaper!
```

**Trade-off:** VPC Endpoints only work for AWS services (S3, DynamoDB). If you need general internet access, NAT is required.

### Recommendation for POC:
1. **Option A (Cheapest):** Use VPC Endpoints, no NAT
2. **Option B (Quick test):** Deploy with NAT, test for 1-2 hours max, destroy immediately
3. **Option C (Production-like):** Use NAT but destroy after each test session

---

## 📋 Testing Phases

### Phase 1: Infrastructure Validation (Quick Deploy) - $0.22

**Duration:** 10 minutes (deploy + validate + destroy)  
**Cost:** $0.22 (NAT Gateway × 3 AZs × 10 min)

⚠️ **IMPORTANT:** Phase 1 creates NAT Gateways which cost $0.045/hour each!

```bash
# 1. Deploy Phase 1 (VPC, S3) - CLOCK STARTS NOW
echo "⏱️  Starting Phase 1 at $(date)"
cd infrastructure/terraform/phases/phase-1
terraform init
terraform plan  # Review resources
terraform apply -auto-approve

# 2. Validate QUICKLY (5 minutes max)
echo "✓ S3 Buckets:"
aws s3 ls | grep poc-chargeback

echo "✓ VPC:"
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=poc-chargeback" \
  --query 'Vpcs[0].VpcId' --output text

echo "✓ NAT Gateways (EXPENSIVE!):"
aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=poc-chargeback" \
  --query 'NatGateways[*].[NatGatewayId,State]' --output table

# 3. Check estimated cost
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-1d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost

# 4. DESTROY IMMEDIATELY if only testing Phase 1
# terraform destroy -auto-approve
```

**Expected Result:** 
- VPC created with 3 NAT Gateways (1 per AZ)
- S3 buckets created
- **Cost: ~$0.22 for 10 minutes**
- 💡 **Keep Phase 1 running ONLY if proceeding immediately to Phase 2**

---

### Phase 2: DynamoDB + Lambda Testing - $0.22/hour (NAT still running)

**Duration:** 30 minutes  
**Cost:** $0.22 (NAT Gateway continues from Phase 1) + $0 (DynamoDB/Lambda free tier)

⚠️ **Phase 1 NAT Gateways continue charging! Test quickly!**

#### 2.1 Deploy Phase 2

```bash
cd infrastructure/terraform/phases/phase-2
terraform init

# Review variables
terraform plan

# Deploy
terraform apply -auto-approve
```

#### 2.2 Insert Test Data (Small Sample)

Create test script: `test-data-generator.sh`

```bash
#!/bin/bash
# Generate 100 test chargebacks (not 5 million!)

DYNAMODB_TABLE="poc-chargeback-dev-chargebacks"

echo "Inserting 100 test chargebacks..."

for i in {1..100}; do
  aws dynamodb put-item \
    --table-name $DYNAMODB_TABLE \
    --item "{
      \"chargeback_id\": {\"S\": \"CB-TEST-$(uuidgen)\"},
      \"status\": {\"S\": \"pending\"},
      \"merchant_id\": {\"S\": \"MERCH-$((RANDOM % 10))\"},
      \"amount\": {\"N\": \"$((RANDOM % 1000 + 10))\"},
      \"currency\": {\"S\": \"USD\"},
      \"created_at\": {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"},
      \"updated_at\": {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"},
      \"reason\": {\"S\": \"Test chargeback $i\"}
    }" \
    --region sa-east-1
  
  # Progress indicator
  if [ $((i % 10)) -eq 0 ]; then
    echo "Inserted $i records..."
  fi
done

echo "✓ Inserted 100 test records"
```

```bash
# Run test data generation
chmod +x test-data-generator.sh
./test-data-generator.sh
```

#### 2.3 Verify Lambda Processing

```bash
# Check Lambda logs
aws logs tail /aws/lambda/poc-chargeback-dev-stream-processor --follow

# Verify DynamoDB Streams are active
aws dynamodb describe-table \
  --table-name poc-chargeback-dev-chargebacks \
  --query 'Table.StreamSpecification'

# Check Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=poc-chargeback-dev-stream-processor \
  --start-time $(date -v-1H -u +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

**Expected Result:** 100 Lambda invocations, DynamoDB Streams active, $0 cost

---

### Phase 3: MSK + Flink Testing - $1.08/hour

**Duration:** 1 hour  
**Cost:** 
- NAT Gateway: $0.22 (still running from Phase 1)
- MSK Serverless: $0.75/hour
- Kinesis Flink: $0.11/hour (1 KPU)
- **Total: ~$1.08 for 1 hour**

⚠️ **IMPORTANT:** MSK Serverless charges by the hour, so **start and stop quickly**.

#### 3.1 Deploy Phase 3

```bash
cd infrastructure/terraform/phases/phase-3

# Review plan first
terraform plan

# Deploy (MSK will start billing)
terraform apply -auto-approve

# Note the start time!
START_TIME=$(date)
echo "MSK Started at: $START_TIME" > /tmp/msk-start-time.txt
```

#### 3.2 Quick Kafka Testing (15 minutes)

```bash
# Get MSK bootstrap servers
BOOTSTRAP_SERVERS=$(terraform output -raw msk_bootstrap_servers)

# Test: Send 10 messages to Kafka
for i in {1..10}; do
  aws kafka-console-producer \
    --bootstrap-server $BOOTSTRAP_SERVERS \
    --topic chargebacks \
    --property "parse.key=true" \
    --property "key.separator=:" <<EOF
CB-TEST-$i:{"chargeback_id":"CB-TEST-$i","status":"pending","amount":100}
EOF
done

# Verify messages received
aws kafka-console-consumer \
  --bootstrap-server $BOOTSTRAP_SERVERS \
  --topic chargebacks \
  --from-beginning \
  --max-messages 10
```

#### 3.3 Test Flink Application (30 minutes)

```bash
# Start Flink application
aws kinesisanalyticsv2 start-application \
  --application-name poc-chargeback-dev-chargeback-processor \
  --region sa-east-1

# Wait 5 minutes for Flink to start
sleep 300

# Trigger DynamoDB updates (which trigger Lambda → Kafka → Flink)
# Update 10 existing records
aws dynamodb scan \
  --table-name poc-chargeback-dev-chargebacks \
  --max-items 10 \
  --query 'Items[].chargeback_id.S' \
  --output text | while read CB_ID; do
    aws dynamodb update-item \
      --table-name poc-chargeback-dev-chargebacks \
      --key "{\"chargeback_id\":{\"S\":\"$CB_ID\"}}" \
      --update-expression "SET #status = :status, updated_at = :timestamp" \
      --expression-attribute-names '{"#status":"status"}' \
      --expression-attribute-values '{":status":{"S":"processing"},":timestamp":{"S":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}}'
    
    echo "Updated $CB_ID"
    sleep 1
  done

# Wait 5 minutes for processing
sleep 300

# Check Flink output in S3
aws s3 ls s3://poc-chargeback-dev-parquet/landing/chargebacks/ --recursive

# Verify Parquet files created
echo "Checking for Parquet files..."
FILE_COUNT=$(aws s3 ls s3://poc-chargeback-dev-parquet/landing/chargebacks/ --recursive | grep ".parquet" | wc -l)
echo "Found $FILE_COUNT Parquet files"
```

#### 3.4 **STOP MSK & Flink Immediately**

```bash
# Stop Flink application
aws kinesisanalyticsv2 stop-application \
  --application-name poc-chargeback-dev-chargeback-processor \
  --region sa-east-1

# Check elapsed time
START_TIME=$(cat /tmp/msk-start-time.txt)
END_TIME=$(date)
echo "MSK ran from $START_TIME to $END_TIME"

# DESTROY Phase 3 to stop billing
terraform destroy -auto-approve

echo "✓ Phase 3 resources destroyed - MSK billing stopped"
```

**Expected Result:** 10 Parquet files in S3, ~$0.75 cost for 1 hour

---

### Phase 4: Glue Testing - $0.40 total

**Duration:** 30 minutes  
**Cost:** 
- NAT Gateway: $0.11 (30 min)
- Glue Crawler: $0.04 (2 runs × 3 min)
- Glue ETL Job: $0.29 (2 workers × 10 min)
- **Total: ~$0.44**

#### 4.1 Deploy Phase 4

```bash
cd infrastructure/terraform/phases/phase-4

# Configure with Phase 3 outputs (but don't enable Kafka - Phase 3 destroyed)
terraform plan \
  -var="enable_kafka_notifications=false" \
  -var="enable_scheduler=false"  # Manual testing only

terraform apply -auto-approve \
  -var="enable_kafka_notifications=false" \
  -var="enable_scheduler=false"
```

#### 4.2 Run Glue Crawler

```bash
# Start crawler
aws glue start-crawler \
  --name poc-chargeback-dev-chargebacks-landing-crawler \
  --region sa-east-1

# Wait for completion (2-5 minutes)
while true; do
  STATE=$(aws glue get-crawler \
    --name poc-chargeback-dev-chargebacks-landing-crawler \
    --query 'Crawler.State' \
    --output text)
  
  echo "Crawler state: $STATE"
  
  if [ "$STATE" == "READY" ]; then
    echo "✓ Crawler completed"
    break
  fi
  
  sleep 30
done

# Verify table created
aws glue get-table \
  --database-name poc-chargeback-dev-chargeback_data \
  --name landing_chargebacks \
  --region sa-east-1
```

#### 4.3 Run Glue ETL Job (Small Dataset)

```bash
# Reduce workers for cost savings (2 workers instead of 10)
aws glue update-job \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --job-update "NumberOfWorkers=2" \
  --region sa-east-1

# Start ETL job
aws glue start-job-run \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --arguments '{
    "--OUTPUT_FORMAT":"csv",
    "--OUTPUT_FILE_COUNT":"1",
    "--ENABLE_KAFKA":"false"
  }' \
  --region sa-east-1

# Get job run ID
JOB_RUN_ID=$(aws glue get-job-runs \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --max-results 1 \
  --query 'JobRuns[0].Id' \
  --output text)

echo "Job Run ID: $JOB_RUN_ID"

# Monitor job (5-10 minutes for small dataset)
while true; do
  JOB_STATE=$(aws glue get-job-run \
    --job-name poc-chargeback-dev-chargebacks-consolidation \
    --run-id $JOB_RUN_ID \
    --query 'JobRun.JobRunState' \
    --output text)
  
  echo "Job state: $JOB_STATE"
  
  if [[ "$JOB_STATE" == "SUCCEEDED" || "$JOB_STATE" == "FAILED" ]]; then
    echo "✓ Job completed: $JOB_STATE"
    break
  fi
  
  sleep 30
done

# Check consolidated output
aws s3 ls s3://poc-chargeback-dev-parquet/consolidated/chargebacks/ --recursive

# Download sample file for verification
aws s3 cp \
  s3://poc-chargeback-dev-parquet/consolidated/chargebacks/year=2025/month=11/day=03/part-00000.csv \
  /tmp/consolidated-sample.csv

# View first 10 lines
head -10 /tmp/consolidated-sample.csv
```

**Expected Result:** Consolidated CSV file with ~100 records, $0.18 cost

---

## 🧪 Complete End-to-End Test Script

Create `test-e2e-minimal.sh`:

```bash
#!/bin/bash
set -e

echo "═══════════════════════════════════════════════════════════"
echo "POC Chargeback - Minimal Cost E2E Test"
echo "Expected Total Cost: < $2.00"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Track costs
START_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
echo "Test started at: $START_TIME"
echo ""

# Phase 1: Infrastructure
echo "► Phase 1: Deploying Infrastructure (VPC, S3)..."
cd infrastructure/terraform/phases/phase-1
terraform init -input=false
terraform apply -auto-approve
echo "✓ Phase 1 complete"
echo ""

# Phase 2: DynamoDB + Lambda
echo "► Phase 2: Deploying DynamoDB + Lambda..."
cd ../phase-2
terraform init -input=false
terraform apply -auto-approve

# Insert test data
echo "► Inserting 50 test records..."
TABLE_NAME=$(terraform output -raw dynamodb_table_name)
for i in {1..50}; do
  aws dynamodb put-item \
    --table-name $TABLE_NAME \
    --item "{
      \"chargeback_id\": {\"S\": \"CB-$(uuidgen)\"},
      \"status\": {\"S\": \"pending\"},
      \"amount\": {\"N\": \"100\"}
    }" >/dev/null 2>&1
  
  if [ $((i % 10)) -eq 0 ]; then echo "  Inserted $i/50..."; fi
done
echo "✓ Phase 2 complete - 50 records inserted"
echo ""

# Phase 3: MSK + Flink (QUICK TEST!)
echo "► Phase 3: Deploying MSK + Flink (⚠️  BILLING STARTS)..."
cd ../phase-3
MSK_START=$(date +%s)
terraform init -input=false
terraform apply -auto-approve

echo "► Testing Kafka + Flink (15 min max)..."
# Quick smoke test
BOOTSTRAP=$(terraform output -raw msk_bootstrap_servers)
echo "  MSK Bootstrap: $BOOTSTRAP"

# Start Flink
aws kinesisanalyticsv2 start-application \
  --application-name poc-chargeback-dev-chargeback-processor >/dev/null 2>&1 || true

# Wait 10 minutes for data to flow
echo "  Waiting 10 minutes for processing..."
sleep 600

# Check S3 output
PARQUET_COUNT=$(aws s3 ls s3://poc-chargeback-dev-parquet/landing/chargebacks/ --recursive | grep ".parquet" | wc -l)
echo "  Found $PARQUET_COUNT Parquet files"

# STOP IMMEDIATELY
echo "► Destroying Phase 3 (⚠️  STOP BILLING)..."
terraform destroy -auto-approve
MSK_END=$(date +%s)
MSK_DURATION=$(( (MSK_END - MSK_START) / 60 ))
echo "✓ Phase 3 complete - MSK ran for $MSK_DURATION minutes"
echo ""

# Phase 4: Glue
echo "► Phase 4: Deploying Glue..."
cd ../phase-4
terraform init -input=false
terraform apply -auto-approve \
  -var="enable_kafka_notifications=false" \
  -var="enable_scheduler=false" \
  -var="glue_job_number_of_workers=2"

# Run crawler
echo "► Running Glue Crawler..."
aws glue start-crawler --name poc-chargeback-dev-chargebacks-landing-crawler
sleep 180  # Wait 3 minutes

# Run ETL job
echo "► Running Glue ETL Job..."
aws glue start-job-run \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --arguments '{"--OUTPUT_FORMAT":"csv","--OUTPUT_FILE_COUNT":"1"}' \
  >/dev/null 2>&1

sleep 300  # Wait 5 minutes
echo "✓ Phase 4 complete"
echo ""

# Final validation
echo "═══════════════════════════════════════════════════════════"
echo "VALIDATION"
echo "═══════════════════════════════════════════════════════════"
echo "1. DynamoDB records: $(aws dynamodb scan --table-name $TABLE_NAME --select COUNT --query 'Count' --output text)"
echo "2. Lambda invocations: $(aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Invocations --dimensions Name=FunctionName,Value=poc-chargeback-dev-stream-processor --start-time $START_TIME --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 3600 --statistics Sum --query 'Datapoints[0].Sum' --output text)"
echo "3. Parquet files: $PARQUET_COUNT"
echo "4. Consolidated files: $(aws s3 ls s3://poc-chargeback-dev-parquet/consolidated/ --recursive | wc -l)"
echo ""
TEST_DURATION=$(( ($(date +%s) - $(date -d $START_TIME +%s)) / 60 ))
NAT_COST=$(echo "scale=2; $TEST_DURATION * 0.135 / 60" | bc)
MSK_COST=$(echo "scale=2; $MSK_DURATION * 0.75 / 60" | bc)
TOTAL_COST=$(echo "scale=2; $NAT_COST + $MSK_COST + 0.40" | bc)

echo "Test duration: $TEST_DURATION minutes"
echo "Estimated costs:"
echo "  - NAT Gateway: \$$NAT_COST"
echo "  - MSK: \$$MSK_COST"
echo "  - Glue: \$0.40"
echo "  - TOTAL: ~\$$TOTAL_COST"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "⚠️  REMEMBER TO RUN: ./cleanup-all.sh"
```

```bash
# Run the complete test
chmod +x test-e2e-minimal.sh
./test-e2e-minimal.sh
```

---

## 🧹 Cleanup Script (CRITICAL!)

Always run cleanup to avoid ongoing charges:

Create `cleanup-all.sh`:

```bash
#!/bin/bash
set -e

echo "🧹 Cleaning up all POC resources..."

# Phase 4
echo "► Destroying Phase 4 (Glue)..."
cd infrastructure/terraform/phases/phase-4
terraform destroy -auto-approve || true

# Phase 3 (most expensive!)
echo "► Destroying Phase 3 (MSK + Flink)..."
cd ../phase-3
terraform destroy -auto-approve || true

# Phase 2
echo "► Destroying Phase 2 (DynamoDB + Lambda)..."
cd ../phase-2
terraform destroy -auto-approve || true

# Phase 1
echo "► Destroying Phase 1 (VPC + S3)..."
cd ../phase-1
terraform destroy -auto-approve || true

echo "✓ All resources destroyed"
echo ""
echo "Verify in AWS Console:"
echo "- MSK clusters: https://console.aws.amazon.com/msk/"
echo "- Flink applications: https://console.aws.amazon.com/flink/"
echo "- Glue jobs: https://console.aws.amazon.com/glue/"
echo "- S3 buckets: https://console.aws.amazon.com/s3/"
```

```bash
# Run cleanup immediately after testing
chmod +x cleanup-all.sh
./cleanup-all.sh
```

---

## 📊 Cost Monitoring

### Real-Time Cost Tracking

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-7d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  --filter file://<(echo '{
    "Tags": {
      "Key": "Project",
      "Values": ["poc-chargeback"]
    }
  }') \
  --query 'ResultsByTime[].Groups[].[Keys[0],Metrics.BlendedCost.Amount]' \
  --output table
```

### Set Billing Alert

```bash
# Create budget alert at $10
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://<(cat <<EOF
{
  "BudgetName": "poc-chargeback-limit",
  "BudgetLimit": {
    "Amount": "10",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
EOF
) \
  --notifications-with-subscribers file://<(cat <<EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "your-email@example.com"
      }
    ]
  }
]
EOF
)
```

---

## 🎯 Recommended Testing Approach

### Option 1: Full Test ($1-2, 2 hours)
- Deploy all phases
- Test with 100 records
- Run MSK for 1 hour only
- Destroy immediately

### Option 2: Phase-by-Phase ($0.50, 3 hours)
- Test each phase separately
- Destroy before moving to next
- MSK only during Phase 3

### Option 3: Local Development ($0)
- Use LocalStack for S3/DynamoDB
- Skip MSK/Flink (most expensive)
- Test Glue scripts locally with PySpark

---

## 💡 Tips to Minimize Costs

1. **🚨 DESTROY NAT GATEWAYS WHEN NOT TESTING**
   - NAT costs $0.22/hour even when idle!
   - Run `terraform destroy` immediately after each session
   - Alternative: Use VPC Endpoints instead ($0.01/hour)

2. **Test in one continuous session**
   - Deploy all phases → Test → Destroy all
   - Don't leave infrastructure running overnight
   - A forgotten NAT Gateway = $32/day!

3. **Use smallest instance sizes**
   - Glue: 2 workers (not 10)
   - Flink: 1 KPU minimum (not auto-scaling)
   - DynamoDB: On-demand (not provisioned)

4. **Test during business hours**
   - Monitor in real-time
   - Destroy immediately if issues
   - Set a phone alarm to destroy after 2 hours!

5. **Use sample data**
   - 100-1000 records (not 5M)
   - Representative but small

6. **Avoid long-running services**
   - MSK: < 1 hour ($0.75/hour)
   - Flink: < 30 minutes
   - Phase 3 is most expensive - test quickly!

7. **Monitor costs in real-time**
   ```bash
   # Check current month costs by service
   aws ce get-cost-and-usage \
     --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
     --granularity DAILY \
     --metrics BlendedCost \
     --group-by Type=SERVICE
   ```

8. **Set billing alerts BEFORE starting**
   - AWS Budget: $5 threshold (alert at 80% = $4)
   - CloudWatch alarm on daily spend
   - Email + SMS notifications

9. **Check what's running RIGHT NOW**
   ```bash
   # List all expensive resources
   echo "NAT Gateways:"
   aws ec2 describe-nat-gateways --filter Name=state,Values=available
   
   echo "MSK Clusters:"
   aws kafka list-clusters-v2
   
   echo "Flink Applications:"
   aws kinesisanalyticsv2 list-applications
   
   echo "Glue Jobs Running:"
   aws glue get-job-runs --job-name poc-chargeback-dev-chargebacks-consolidation --max-results 5
   ```

---

## ✅ Success Criteria

Your POC is validated when:

- ✅ DynamoDB records inserted successfully
- ✅ Lambda processes DynamoDB Streams
- ✅ Kafka receives chargeback events
- ✅ Flink writes Parquet files to S3
- ✅ Glue Crawler discovers schema
- ✅ Glue ETL consolidates to CSV
- ✅ Total cost < $5 for complete test
- ✅ All resources destroyed after testing (verify NAT Gateways deleted!)

---

## 🚨 Emergency Shutdown

If costs are spiraling:

```bash
# Stop everything NOW
cd infrastructure/terraform/phases/phase-3
terraform destroy -auto-approve  # Kill MSK immediately

cd ../phase-4
terraform destroy -auto-approve  # Kill Glue

# Check what's still running
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=poc-chargeback \
  --resource-type-filters \
    kafka:cluster \
    kinesisanalytics:application \
    glue:job
```

---

## 📊 Realistic Cost Summary

### Scenario 1: Quick Test (2 hours total)
- Phase 1: Deploy + validate (10 min) = $0.22
- Phase 2: DynamoDB/Lambda test (30 min) = $0.11 (NAT only)
- Phase 3: MSK + Flink (1 hour) = $1.08
- Phase 4: Glue jobs (30 min) = $0.44
- **Total: ~$1.85-$2.00** ✅

### Scenario 2: Full Day Testing (8 hours)
- NAT Gateway: 8 hours = $10.80 ⚠️
- MSK: 2 hours = $1.50
- Flink: 2 hours = $0.22
- Glue: Multiple runs = $1.00
- **Total: ~$13.50** 💸

### Scenario 3: FORGOT TO DESTROY (24 hours)
- NAT Gateway: 24 hours = **$32.40** 🔥
- MSK: 8 hours = $6.00
- **Total: ~$38.00** 💀

### Scenario 4: Cost-Optimized (VPC Endpoints)
Replace NAT Gateway with VPC Endpoints in Phase 1 variables:
```hcl
enable_nat_gateway = false
enable_vpc_endpoints = true
```
- VPC Endpoints: 2 hours = $0.02 (vs $0.27 NAT)
- MSK: 1 hour = $0.75
- Flink: 1 hour = $0.11
- Glue: 2 runs = $0.44
- **Total: ~$1.32** ✅ Best Option!

---

**💰 REALISTIC Expected Cost: $2-5 for complete POC validation**

**🚨 CRITICAL: Always run cleanup script immediately after testing to avoid $32/day NAT costs!**

```bash
# Set a reminder NOW
echo "cd ~/Documents/Workspace/poc-chargeback-aws && ./cleanup-all.sh" | at now + 2 hours
```
