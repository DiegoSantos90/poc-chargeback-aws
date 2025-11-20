# Phase 4: Data Consolidation with AWS Glue - Implementation Guide

## 📋 Overview

Phase 4 addresses the **data consolidation challenge** created by Phase 3's 1:1 processing model. While Phase 3 generates one Parquet file per chargeback event (potentially thousands of small files per day), Phase 4 consolidates these into optimized, partitioned datasets using AWS Glue for efficient querying and analytics.

## 🎯 Phase 4 Objectives

- ✅ **Schema Discovery**: Auto-discover schema and partitions with Glue Crawler
- ✅ **Data Cataloging**: Centralized metadata in Glue Data Catalog
- ✅ **Data Consolidation**: PySpark ETL to merge small files into optimized datasets
- ✅ **Flexible Output**: Support CSV, Parquet, or JSON formats (parametrized)
- ✅ **Kafka Integration**: Send consolidation events to MSK for DynamoDB updates
- ✅ **Scheduled Execution**: EventBridge Scheduler triggers jobs N times per day (parametrized)
- ✅ **Scalability**: Support up to 5 million chargebacks per day
- ✅ **Cost Optimization**: Lifecycle policies and intelligent tiering
- ✅ **Monitoring**: CloudWatch dashboard, alarms, and metrics

## 🚨 The Problem Phase 4 Solves

### Current State (After Phase 3):
```
S3 Landing Zone:
├── landing/chargebacks/2025/11/03/
│   ├── chargeback_001.parquet (50 KB)
│   ├── chargeback_002.parquet (50 KB)
│   ├── chargeback_003.parquet (50 KB)
│   ├── ... (thousands more files)
│   └── chargeback_10000.parquet (50 KB)
```

**Problems:**
- ❌ **Too many small files** → Slow S3 LIST operations (high latency)
- ❌ **High query costs** → Athena/analytics charge per file scanned
- ❌ **Poor compression** → Small files can't leverage columnar compression effectively
- ❌ **Slow queries** → Opening thousands of files takes significant time
- ❌ **Metadata overhead** → Each file has its own Parquet footer/metadata

### Solution (Phase 4):
```
S3 Consolidated Zone:
├── consolidated/chargebacks/year=2025/month=11/day=03/
│   ├── part-00000.csv (100 MB) ← 1,250 small files consolidated
│   ├── part-00001.csv (100 MB)
│   ├── ... (8 more files)
│   └── part-00009.csv (100 MB)
```

**Benefits:**
- ✅ **10-1000x fewer files** → Fast S3 operations
- ✅ **10x lower query costs** → Fewer files to scan
- ✅ **Better compression** → 5-10x compression ratio
- ✅ **10x faster queries** → Reduced I/O overhead
- ✅ **Flexible formats** → CSV (human-readable), Parquet (analytics), JSON (APIs)
- ✅ **Event-driven** → Kafka notifications for downstream processing

## 🏗️ Phase 4 Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                        PHASE 4 WORKFLOW                            │
└────────────────────────────────────────────────────────────────────┘

    S3 Landing Zone              AWS Glue Services          S3 Consolidated
    (Phase 3 Output)                                        (Phase 4 Output)
         │                                                        │
         │  1. Schema Discovery                                  │
    ┌────▼──────────┐         ┌───────────────────┐      ┌───────▼────────┐
    │ 10,000 files  │────────▶│  Glue Crawler     │      │ Optimized Data │
    │ per day       │         │  - Runs 4x/day    │      │                │
    │ 50 KB each    │         │  - Discovers      │      │ Partitioned:   │
    │               │         │    schema         │      │ • Year         │
    │ Partitioned:  │         │  - Auto-detects   │      │ • Month        │
    │ YYYY/MM/DD/   │         │    partitions     │      │ • Day          │
    └───────────────┘         └─────────┬─────────┘      │                │
                                        │                 │ 10 files/exec  │
                                        │                 │ 40 files/day   │
                              ┌─────────▼─────────┐      │ 100 MB each    │
                              │ Glue Data Catalog │      │                │
                              │  - Central schema │      │ Benefits:      │
                              │  - Table metadata │      │ • Fast queries │
                              │  - Partitions     │      │ • Compressed   │
                              └─────────┬─────────┘      │ • Columnar     │
                                        │                 └────────────────┘
                    2. Schedule Triggers│
                              ┌─────────▼─────────┐
                              │ EventBridge       │
                              │ Scheduler (4x)    │
                              │                   │
                              │ • 00:30 BRT       │
                              │ • 06:30 BRT       │
                              │ • 12:30 BRT       │
                              │ • 18:30 BRT       │
                              └─────────┬─────────┘
                                        │
                    3. ETL Processing   │
                              ┌─────────▼─────────┐
                              │ Glue ETL Job      │
                              │ (PySpark)         │
                              │                   │
                              │ • Read landing    │
                              │ • Deduplicate     │
                              │ • Quality checks  │
                              │ • Repartition     │
                              │ • Write CSV/      │
                              │   Parquet/JSON    │
                              └─────────┬─────────┘
                                        │
                                        │ 4. Kafka Event
                              ┌─────────▼─────────┐
                              │ MSK Serverless    │
                              │ (Phase 3)         │
                              │                   │
                              │ Topic:            │
                              │ consolidation-    │
                              │ events            │
                              └─────────┬─────────┘
                                        │
                              ┌─────────▼─────────┐
                              │ Lambda (Future)   │
                              │ Updates DynamoDB  │
                              └─────────┬─────────┘
                                        │
                    5. Monitoring       │
                              ┌─────────▼─────────┐
                              │ CloudWatch        │
                              │ • Dashboard       │
                              │ • Alarms          │
                              │ • Metrics         │
                              │ • Logs            │
                              └───────────────────┘
```

## 📁 Project Structure

```
infrastructure/terraform/phases/phase-4/
├── variables.tf              # Configuration (executions/day, file count, formats, Kafka)
├── data-sources.tf            # Phase 1 imports and locals
├── glue-catalog.tf            # Database and table definitions
├── glue-crawler.tf            # Schema discovery crawler
├── iam.tf                     # IAM roles (Glue, EventBridge, MSK access)
├── glue-etl-job.tf            # ETL job configuration with VPC connection
├── eventbridge-scheduler.tf   # Scheduled triggers (N times/day)
├── s3-lifecycle.tf            # Data retention policies
├── cloudwatch.tf              # Monitoring and alarms
├── kafka-topic.tf             # Kafka topic creation and MSK connectivity
└── outputs.tf                 # Exported values and commands

deployments/glue-jobs/
├── consolidate_chargebacks.py # PySpark script (CSV/Parquet/JSON + Kafka)
└── README.md                  # Script documentation
```

## 🚀 Resources Created

### AWS Glue Data Catalog
- **1x Glue Database**: `poc-chargeback-dev-chargeback_data`
- **2x Glue Tables**:
  - `landing_chargebacks` (auto-created by crawler)
  - `chargebacks_consolidated` (manually defined with schema)

### AWS Glue Crawler
- **Name**: `poc-chargeback-dev-chargebacks-landing-crawler`
- **Schedule**: 4 times/day (before ETL jobs)
- **Target**: Landing zone S3 path
- **Behavior**: Discovers schema, creates/updates partitions
- **Configuration**: Crawls new folders only (performance optimization)

### AWS Glue ETL Job
- **Name**: `poc-chargeback-dev-chargebacks-consolidation`
- **Runtime**: Glue 3.0 (Spark 3.1, Python 3.7)
- **Workers**: 10 × G.1X (4 vCPU, 16 GB each)
- **Total Capacity**: 10 DPUs
- **Timeout**: 60 minutes
- **Script**: PySpark consolidation logic (auto-uploaded to S3)
- **Features**: Multi-format output (CSV/Parquet/JSON), Kafka producer, deduplication
- **VPC Connection**: Optional connection to MSK for Kafka integration

### EventBridge Schedulers
- **Count**: 4 schedulers (parametrized via `consolidation_executions_per_day`)
- **Schedule**: 
  - Scheduler 1: 00:30 America/Sao_Paulo
  - Scheduler 2: 06:30 America/Sao_Paulo
  - Scheduler 3: 12:30 America/Sao_Paulo
  - Scheduler 4: 18:30 America/Sao_Paulo
- **Target**: Glue ETL Job (with execution sequence metadata)
- **Retry**: 2 retries with 1-hour event age limit

### IAM Roles
- **Glue Service Role**: Permissions for S3, Catalog, CloudWatch, MSK/Kafka access
- **EventBridge Scheduler Role**: Permission to start Glue jobs

### MSK/Kafka Integration (Optional)
- **Kafka Topic**: `chargeback-consolidation-events` (3 partitions, replication factor 3)
- **Security Groups**: Glue to MSK connectivity on port 9098 (IAM auth)
- **Glue Connection**: VPC connection for MSK access
- **Event Format**: JSON messages with consolidation metadata

### S3 Lifecycle Policies
- **Landing Zone Cleanup**: Delete after N days (parametrized, disabled for POC)
- **Consolidated Archival**: Transition to Glacier after 90 days (parametrized)
- **Glue Temp Cleanup**: Auto-delete after 1 day (always enabled)

### CloudWatch Monitoring
- **Dashboard**: 6 widgets with metrics, logs, and status visualization
- **Log Groups**: Crawler logs, ETL job logs (7-day retention)
- **Alarms**: Job failures, timeouts, success rate
- **SNS Topic**: Email notifications for failures (optional)
- **Metric Filters**: Custom metrics from logs

## 📊 Data Processing Flow

### Daily Processing (4 Executions Example)

```
Time    | Event                 | Details
--------|----------------------|------------------------------------------
00:00   | Crawler Run 1        | Discovers data from 18:00-00:00 (6h window)
00:30   | ETL Execution 1      | Consolidates ~1.25M records → 1 file
06:00   | Crawler Run 2        | Discovers data from 00:00-06:00 (6h window)
06:30   | ETL Execution 2      | Consolidates ~1.25M records → 1 file
12:00   | Crawler Run 3        | Discovers data from 06:00-12:00 (6h window)
12:30   | ETL Execution 3      | Consolidates ~1.25M records → 1 file
18:00   | Crawler Run 4        | Discovers data from 12:00-18:00 (6h window)
18:30   | ETL Execution 4      | Consolidates ~1.25M records → 1 file
```

**Daily Summary**:
- **Input**: ~10,000+ small files (50 KB each) from landing zone
- **Output**: 4 consolidated files total (1 file × 4 executions)
- **File Size**: ~400 MB each (after consolidation)
- **Total Records**: 5,000,000 records processed per day
- **Reduction**: 2,500x fewer files (10,000 → 4)

## ⚙️ Configuration Parameters

### Key Variables (in `variables.tf`)

| Variable | Default | Description |
|----------|---------|-------------|
| `consolidation_executions_per_day` | 4 | Number of times to run consolidation (2, 4, 8, 12, 24) |
| `consolidation_output_files` | 1 | Number of files per execution (1 = single file) |
| `glue_job_worker_type` | G.1X | Worker size (G.1X, G.2X, G.4X, G.8X) |
| `glue_job_number_of_workers` | 10 | Number of workers (scale for volume) |
| `parquet_compression_codec` | snappy | Compression (snappy, gzip, lzo, zstd) |
| `landing_zone_retention_enabled` | false | Delete landing files after consolidation |
| `landing_zone_retention_days` | 7 | Days to keep landing files |
| `scheduler_timezone` | America/Sao_Paulo | Timezone for schedules |
| `enable_cloudwatch_alarms` | true | Enable monitoring alarms |

### Output Format Configuration

| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `output_format` | csv | csv, parquet, json | Output file format |
| `csv_delimiter` | , | any char | Delimiter for CSV files |
| `csv_header` | true | true, false | Include header row in CSV |
| `csv_quote_char` | " | any char | Quote character for CSV |
| `parquet_compression_codec` | snappy | snappy, gzip, zstd | Parquet compression (if format=parquet) |

**Format Comparison:**

| Format | Best For | Pros | Cons |
|--------|----------|------|------|
| **CSV** | Operational use, manual inspection | Human-readable, universal compatibility, simple processing | Larger size, no schema enforcement |
| **Parquet** | Analytics, BI tools | Columnar, highly compressed, schema embedded | Binary format, needs special tools |
| **JSON** | APIs, NoSQL databases | Flexible schema, nested structures | Larger size, slower to parse |

### Kafka Integration Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_kafka_notifications` | true | Enable Kafka event publishing |
| `msk_bootstrap_brokers` | "" | MSK bootstrap servers (from Phase 3) |
| `kafka_consolidation_topic` | chargeback-consolidation-events | Topic name for events |
| `kafka_consolidation_topic_partitions` | 3 | Number of topic partitions |
| `kafka_consolidation_topic_replication` | 3 | Replication factor (MSK Serverless = 3) |
| `msk_security_group_id` | "" | MSK security group (from Phase 3) |
| `vpc_id` | "" | VPC ID (from Phase 1) |
| `private_subnet_ids` | [] | Private subnets for Glue connection |

**Kafka Event Schema:**

```json
{
  "event_type": "consolidation_completed",
  "partition_date": "2025-11-03",
  "execution_sequence": 2,
  "total_executions": 4,
  "records_processed": 1250000,
  "duplicates_removed": 150,
  "output_files": 10,
  "output_format": "csv",
  "output_path": "s3://bucket/consolidated/chargebacks/year=2025/month=11/day=03",
  "execution_time": "2025-11-03T06:30:00",
  "completed_at": "2025-11-03T06:45:32.123456+00:00",
  "job_name": "poc-chargeback-dev-chargebacks-consolidation"
}
```

**Use Case**: Lambda function consumes these events to update DynamoDB chargeback status in real-time.

### Scaling Configuration

**For 5 Million Records/Day** (Default):
```hcl
glue_job_worker_type       = "G.1X"
glue_job_number_of_workers = 10
consolidation_executions_per_day = 4
consolidation_output_files = 1
# Result: 10-15 minutes per execution, 4 files per day
```

**For 10 Million Records/Day**:
```hcl
glue_job_worker_type       = "G.2X"  # More powerful workers
glue_job_number_of_workers = 20      # Double capacity
consolidation_executions_per_day = 4
consolidation_output_files = 1       # Still 1 file per execution
# Result: 15-20 minutes per execution, 4 files per day
```

**For Real-Time (Hourly)**:
```hcl
glue_job_worker_type       = "G.1X"
glue_job_number_of_workers = 5       # Smaller batches
consolidation_executions_per_day = 24 # Every hour
consolidation_output_files = 1       # 1 file per hour
# Result: 5-10 minutes per execution, 24 files per day
```

## 🚀 Deployment Guide

### Prerequisites

1. **Phase 1 Deployed**: S3 Parquet bucket must exist
2. **Phase 3 Deployed** (Optional): For end-to-end testing with real data
3. **Terraform 1.0+**: Infrastructure provisioning
4. **AWS CLI**: For manual testing and verification

### Step 1: Get Dependencies from Other Phases

```bash
cd infrastructure/terraform/phases/phase-4

# Get S3 bucket from Phase 1
cd ../phase-1
BUCKET_NAME=$(terraform output -raw parquet_bucket_name)
BUCKET_ARN=$(terraform output -raw parquet_bucket_arn)
VPC_ID=$(terraform output -raw vpc_id)
PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids | jq -r '. | @json')
cd ../phase-4

# Get MSK info from Phase 3 (if Kafka integration desired)
cd ../phase-3
MSK_BROKERS=$(terraform output -raw msk_bootstrap_brokers)
MSK_SG=$(terraform output -raw msk_security_group_id)
cd ../phase-4
```

### Step 2: Review Configuration

```bash
# Review default configuration
cat variables.tf

# Create terraform.tfvars with your configuration
cat > terraform.tfvars <<EOF
project_name = "poc-chargeback"
environment  = "dev"

# S3 bucket (from Phase 1)
parquet_bucket_name = "$BUCKET_NAME"
parquet_bucket_arn  = "$BUCKET_ARN"

# Output format
output_format = "csv"      # Options: csv, parquet, json
csv_delimiter = ","
csv_header    = true

# Consolidation settings
consolidation_executions_per_day = 4
consolidation_output_files       = 1

# Glue job sizing
glue_job_worker_type       = "G.1X"
glue_job_number_of_workers = 10

# Kafka integration (optional - set enable_kafka_notifications=false to disable)
enable_kafka_notifications = true
msk_bootstrap_brokers      = "$MSK_BROKERS"
kafka_consolidation_topic  = "chargeback-consolidation-events"
msk_security_group_id      = "$MSK_SG"
vpc_id                     = "$VPC_ID"
private_subnet_ids         = $PRIVATE_SUBNETS

# Monitoring
enable_cloudwatch_alarms = true
alarm_email_endpoints    = ["your-email@company.com"]

# Retention (enable after POC)
landing_zone_retention_enabled = false
EOF
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Plan Deployment

```bash
terraform plan -out=phase4.tfplan

# Review what will be created:
# - 1 Glue database
# - 2 Glue tables
# - 1 Glue crawler
# - 1 Glue ETL job
# - 4 EventBridge schedulers
# - 2 IAM roles
# - 3 S3 lifecycle rules
# - 1 CloudWatch dashboard
# - 5+ CloudWatch alarms
# - 1 SNS topic (if email endpoints provided)
```

### Step 5: Deploy Infrastructure

```bash
terraform apply phase4.tfplan

# Deployment time: ~2-3 minutes
```

### Step 6: Verify Deployment

```bash
# Check Glue resources
terraform output glue_database
terraform output glue_crawler
terraform output glue_job
terraform output eventbridge_schedulers

# View CloudWatch dashboard URL
terraform output cloudwatch_dashboard_url

# Get operational commands
terraform output operational_commands
```

## 🧪 Testing Phase 4

### Test 1: Manual Crawler Run

```bash
# Get crawler name
CRAWLER_NAME=$(terraform output -raw glue_crawler_name)

# Start crawler
aws glue start-crawler \
  --name $CRAWLER_NAME \
  --region sa-east-1

# Check crawler status
aws glue get-crawler \
  --name $CRAWLER_NAME \
  --region sa-east-1 \
  --query 'Crawler.State' \
  --output text

# Wait for crawler to complete (5-10 minutes)
aws glue get-crawler \
  --name $CRAWLER_NAME \
  --region sa-east-1 \
  --query 'Crawler.{State:State,LastUpdated:LastCrawl.Status}' \
  --output table

# Verify table was created
aws glue get-table \
  --database-name $(terraform output -raw glue_database_name) \
  --name landing_chargebacks \
  --region sa-east-1 \
  --query 'Table.{Name:Name,RecordCount:Parameters.recordCount,Partitions:PartitionKeys}' \
  --output table
```

### Test 2: Manual ETL Job Run

```bash
# Get job name
JOB_NAME=$(terraform output -raw glue_job_name)

# Start ETL job (processes yesterday's data by default)
JOB_RUN_ID=$(aws glue start-job-run \
  --job-name $JOB_NAME \
  --region sa-east-1 \
  --query 'JobRunId' \
  --output text)

echo "Job Run ID: $JOB_RUN_ID"

# Monitor job status
aws glue get-job-run \
  --job-name $JOB_NAME \
  --run-id $JOB_RUN_ID \
  --region sa-east-1 \
  --query 'JobRun.{Status:JobRunState,StartedOn:StartedOn,ExecutionTime:ExecutionTime}' \
  --output table

# Tail job logs in real-time
aws logs tail /aws-glue/jobs/$JOB_NAME \
  --follow \
  --region sa-east-1
```

### Test 3: Run with Custom Parameters

```bash
# Process specific date with custom file count
aws glue start-job-run \
  --job-name $JOB_NAME \
  --region sa-east-1 \
  --arguments '{
    "--PARTITION_DATE":"2025-11-02",
    "--OUTPUT_FILE_COUNT":"1"
  }'

# Dry run (no output written)
aws glue start-job-run \
  --job-name $JOB_NAME \
  --region sa-east-1 \
  --arguments '{"--DRY_RUN":"true"}'
```

### Test 4: Verify Consolidated Data

```bash
# Get S3 paths
BUCKET=$(terraform output -raw parquet_bucket_name)
CONSOLIDATED_PREFIX=$(terraform output -json s3_paths | jq -r '.consolidated')

# List consolidated files
aws s3 ls ${CONSOLIDATED_PREFIX}/year=2025/month=11/day=02/ --human-readable

# Count records in consolidated data (using Athena)
DATABASE=$(terraform output -raw glue_database_name)

aws athena start-query-execution \
  --query-string "SELECT COUNT(*) FROM ${DATABASE}.chargebacks_consolidated WHERE year='2025' AND month='11' AND day='02'" \
  --result-configuration "OutputLocation=s3://${BUCKET}/athena-results/" \
  --region sa-east-1
```

### Test 5: EventBridge Scheduler Verification

```bash
# List all schedulers
aws scheduler list-schedules \
  --name-prefix poc-chargeback-dev-consolidation \
  --region sa-east-1

# Get specific scheduler details
SCHEDULER_NAME=$(terraform output -json scheduler_names | jq -r '.[0]')

aws scheduler get-schedule \
  --name $SCHEDULER_NAME \
  --region sa-east-1 \
  --query '{Name:Name,State:State,Schedule:ScheduleExpression,Target:Target.Arn}' \
  --output table

# Check scheduler history (recent invocations)
aws scheduler list-schedule-groups \
  --region sa-east-1
```

### Test 6: Verify Kafka Integration (if enabled)

```bash
# Check if Kafka topic was created
aws kafka list-topics \
  --cluster-name poc-chargeback-dev-chargebacks-cluster \
  --region sa-east-1

# Verify Glue security group allows MSK access
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$(terraform output -raw glue_security_group_id)" \
  --region sa-east-1

# Run a consolidation job and check for Kafka messages in logs
aws logs filter-log-events \
  --log-group-name /aws-glue/jobs/$(terraform output -raw glue_job_name) \
  --filter-pattern "Kafka" \
  --region sa-east-1

# Consumer test (requires EC2 instance in same VPC with Kafka tools)
# kafka-console-consumer.sh \
#   --bootstrap-server $MSK_BROKERS \
#   --topic chargeback-consolidation-events \
#   --from-beginning \
#   --consumer.config client.properties
```

### Test 7: Verify CSV Output Format

```bash
# List consolidated CSV files
aws s3 ls s3://$BUCKET_NAME/consolidated/chargebacks/year=2025/month=11/day=03/ \
  --human-readable

# Download a sample file to verify format
aws s3 cp \
  s3://$BUCKET_NAME/consolidated/chargebacks/year=2025/month=11/day=03/part-00000.csv \
  /tmp/sample.csv

# View first 10 lines
head -n 10 /tmp/sample.csv

# Count records in CSV
wc -l /tmp/sample.csv
```

## 📊 Monitoring and Operations

### CloudWatch Dashboard

Access the dashboard to visualize:
- Job execution status (completed/failed stages and tasks)
- Execution time trends (average, min, max)
- Data volume processed (records, bytes read/written)
- Resource utilization (CPU, memory, disk)
- Recent crawler activity
- Job errors and exceptions

```bash
# Open dashboard in browser
open $(terraform output -raw cloudwatch_dashboard_url)
```

### CloudWatch Logs Insights Queries

**Query 1: Job Execution Summary**
```
SOURCE '/aws-glue/jobs/poc-chargeback-dev-chargebacks-consolidation'
| fields @timestamp, @message
| filter @message like /METRICS:/
| parse @message "records_processed=*, duplicates_removed=*, output_files=*, duration_seconds=*" 
    as records, duplicates, files, duration
| stats 
    sum(records) as total_records,
    sum(duplicates) as total_duplicates,
    avg(duration) as avg_duration_sec,
    max(duration) as max_duration_sec
  by bin(1h)
| sort @timestamp desc
```

**Query 2: Error Analysis**
```
SOURCE '/aws-glue/jobs/poc-chargeback-dev-chargebacks-consolidation'
| fields @timestamp, @message
| filter @message like /ERROR/ or @message like /Exception/
| sort @timestamp desc
| limit 50
```

**Query 3: Processing Rate**
```
SOURCE '/aws-glue/jobs/poc-chargeback-dev-chargebacks-consolidation'
| fields @timestamp, @message
| filter @message like /Consolidation completed/
| parse @message "*records_processed=*, duplicates_removed=*, output_files=*, duration_seconds=*" 
    as prefix, records, duplicates, files, duration
| fields @timestamp, records / duration as records_per_sec
| sort @timestamp desc
```

### CloudWatch Alarms

**Configured Alarms**:
1. **Crawler Failure**: Triggers when crawler fails
2. **Job Failure**: Triggers when ETL job fails
3. **Job Timeout**: Triggers when job exceeds 30 minutes
4. **Daily Success Rate**: Triggers when <75% of daily jobs succeed

**SNS Email Notifications**:
```bash
# Add email endpoint after deployment
aws sns subscribe \
  --topic-arn $(terraform output -raw sns_topic_arn) \
  --protocol email \
  --notification-endpoint your-email@company.com \
  --region sa-east-1

# Confirm subscription via email link
```

### Operational Commands

```bash
# Start crawler
aws glue start-crawler --name $(terraform output -raw glue_crawler_name) --region sa-east-1

# Start ETL job
aws glue start-job-run --job-name $(terraform output -raw glue_job_name) --region sa-east-1

# Get crawler status
aws glue get-crawler --name $(terraform output -raw glue_crawler_name) --region sa-east-1 --query 'Crawler.State'

# List recent job runs
aws glue get-job-runs --job-name $(terraform output -raw glue_job_name) --region sa-east-1 --max-results 10

# View crawler logs
aws logs tail /aws-glue/crawlers/$(terraform output -raw glue_crawler_name) --follow --region sa-east-1

# View job logs
aws logs tail /aws-glue/jobs/$(terraform output -raw glue_job_name) --follow --region sa-east-1

# Stop running job (if needed)
aws glue batch-stop-job-run \
  --job-name $(terraform output -raw glue_job_name) \
  --job-run-ids <job-run-id> \
  --region sa-east-1
```

## 💰 Cost Analysis

### Monthly Cost Breakdown (5M Records/Day)

| Component | Usage | Unit Cost | Monthly Cost |
|-----------|-------|-----------|--------------|
| **Glue Crawler** | 120 runs × 5 min | $0.44/DPU-hour | **$2.20** |
| **Glue ETL Job** | 120 runs × 20 min × 10 DPUs | $0.44/DPU-hour | **$35.20** |
| **Glue Data Catalog** | <1M objects | First 1M free | **$0.00** |
| **S3 Storage (Landing)** | 150 GB × 7 days | $0.023/GB | **$3.45** |
| **S3 Storage (Consolidated)** | 150 GB × 30 days | $0.023/GB | **$3.45** |
| **EventBridge Scheduler** | 120 invocations | Free tier | **$0.00** |
| **CloudWatch Logs** | 2 GB ingested | $0.50/GB | **$1.00** |
| **CloudWatch Metrics** | Custom metrics | Included | **$0.00** |
| **SNS Notifications** | <1000 emails | First 1000 free | **$0.00** |
| **Kafka Topic Storage** | <1 GB events | $0.10/GB | **$0.10** |
| **Lambda Invocations** | 120/month | $0.20/1M | **$0.00** |
| **TOTAL** | | | **~$45.40/month** |

### Cost Optimization Tips

1. **Reduce Crawler Frequency**: If schema doesn't change often, run less frequently
2. **Adjust Worker Count**: Start with fewer workers and scale up as needed
3. **Enable Landing Zone Cleanup**: Delete files after 7 days to save storage
4. **Use Spot Instances**: Not available for Glue, but consider EMR for large-scale batch
5. **Optimize File Count**: Larger files (fewer of them) = lower overhead

### Cost Comparison

| Scenario | Monthly Cost | Notes |
|----------|--------------|-------|
| **POC (Current)** | $45 | 5M records/day, 4 executions, CSV output, Kafka enabled |
| **POC (Parquet)** | $45 | Same but with Parquet (better compression) |
| **Production (10M)** | $90 | Double workers, same frequency |
| **Real-Time (Hourly)** | $65 | 24 executions, fewer workers per run |
| **Without Consolidation** | $200+ | Athena scans 10,000+ files (10x cost) |

**Format Impact:**
- CSV: ~20-30% larger than Parquet but human-readable
- Parquet: Best compression, fastest queries
- JSON: Largest files, flexible schema

**ROI**: Phase 4 consolidation saves 10x on query costs, pays for itself quickly!

## 🐛 Troubleshooting

### Issue: Crawler finds no tables

**Symptoms**:
- Crawler completes successfully
- No tables appear in Data Catalog

**Causes**:
- Landing zone has no data
- Incorrect S3 path
- Phase 3 Flink not writing data

**Solutions**:
```bash
# Check if landing zone has data
BUCKET=$(terraform output -raw parquet_bucket_name)
aws s3 ls s3://${BUCKET}/landing/chargebacks/ --recursive | head -20

# Verify crawler target path
aws glue get-crawler --name $(terraform output -raw glue_crawler_name) \
  --region sa-east-1 --query 'Crawler.Targets.S3Targets'

# Check Phase 3 Flink is running and writing data
```

### Issue: ETL job fails with "No data found for partition"

**Symptoms**:
- Job completes successfully but logs warning "No data found"

**Causes**:
- Crawler hasn't discovered the partition yet
- Processing date has no data
- Partition filter is incorrect

**Solutions**:
```bash
# Run crawler first to discover partitions
aws glue start-crawler --name $(terraform output -raw glue_crawler_name)

# Check available partitions
aws glue get-partitions \
  --database-name $(terraform output -raw glue_database_name) \
  --table-name landing_chargebacks \
  --region sa-east-1

# Run job for specific date with data
aws glue start-job-run \
  --job-name $(terraform output -raw glue_job_name) \
  --arguments '{"--PARTITION_DATE":"2025-11-02"}' \
  --region sa-east-1
```

### Issue: Job times out after 60 minutes

**Symptoms**:
- Job fails with timeout error
- CloudWatch shows job still processing

**Causes**:
- Too much data for current worker configuration
- Inefficient queries (full table scans)
- Network issues reading from S3

**Solutions**:
```bash
# Option 1: Increase workers
# Edit variables.tf:
glue_job_number_of_workers = 20  # Double capacity

# Option 2: Use larger worker type
glue_job_worker_type = "G.2X"    # 8 vCPU, 32 GB RAM

# Option 3: Increase timeout
glue_job_timeout = 120  # 2 hours

# Option 4: Process smaller time windows
# Run job multiple times for specific hours instead of full day

terraform apply
```

### Issue: Output file count doesn't match expected

**Symptoms**:
- Requested 10 files, got 8 or 12

**Causes**:
- Spark adaptive execution coalescing small partitions
- Data skew causing uneven distribution

**Solutions**:
This is normal and expected! Spark optimizes automatically. The variance is usually ±20%.

```python
# If exact count is critical, disable adaptive coalescing in script:
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "false")
```

### Issue: Duplicates not being removed

**Symptoms**:
- Consolidated data has duplicate chargeback_ids

**Causes**:
- Missing `updated_at` timestamps in source data
- Deduplication window function not working

**Solutions**:
```bash
# Check source data quality
aws glue start-job-run \
  --job-name $(terraform output -raw glue_job_name) \
  --arguments '{"--DRY_RUN":"true"}' \
  --region sa-east-1

# View logs for duplicate warnings
aws logs tail /aws-glue/jobs/$(terraform output -raw glue_job_name) \
  --follow --region sa-east-1 | grep "duplicate"

# Modify deduplication logic in consolidate_chargebacks.py if needed
```

### Issue: EventBridge Scheduler not triggering

**Symptoms**:
- Scheduled time passes, no job starts

**Causes**:
- Scheduler is disabled
- IAM role lacks permissions
- Incorrect timezone configuration

**Solutions**:
```bash
# Check scheduler state
SCHEDULER_NAME=$(terraform output -json scheduler_names | jq -r '.[0]')
aws scheduler get-schedule --name $SCHEDULER_NAME --region sa-east-1 --query 'State'

# Enable if disabled
aws scheduler update-schedule \
  --name $SCHEDULER_NAME \
  --state ENABLED \
  --region sa-east-1

# Check scheduler execution history
aws cloudwatch get-metric-statistics \
  --namespace AWS/Events \
  --metric-name Invocations \
  --dimensions Name=ScheduleName,Value=$SCHEDULER_NAME \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --region sa-east-1
```

## � DynamoDB Integration via Kafka (Next Steps)

### Lambda Consumer Function

Create a Lambda function to consume Kafka consolidation events and update DynamoDB:

```python
import json
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('poc-chargeback-dev-chargebacks')

def lambda_handler(event, context):
    """
    Consumes Kafka consolidation events and updates DynamoDB status.
    Triggered by MSK event source mapping.
    """
    processed = 0
    errors = 0
    
    for topic, records in event['records'].items():
        for record in records:
            try:
                # Decode Kafka message (base64 encoded)
                import base64
                message_bytes = base64.b64decode(record['value'])
                message = json.loads(message_bytes)
                
                partition_date = message['partition_date']
                
                # Update DynamoDB with consolidation status
                table.update_item(
                    Key={'partition_date': partition_date},
                    UpdateExpression='''
                        SET consolidation_status = :status,
                            consolidation_completed_at = :completed_at,
                            records_consolidated = :records,
                            output_files = :files,
                            output_format = :format,
                            output_path = :path,
                            last_updated = :updated
                    ''',
                    ExpressionAttributeValues={
                        ':status': 'completed',
                        ':completed_at': message['completed_at'],
                        ':records': message['records_processed'],
                        ':files': message['output_files'],
                        ':format': message['output_format'],
                        ':path': message['output_path'],
                        ':updated': datetime.utcnow().isoformat()
                    }
                )
                
                processed += 1
                print(f"✓ Updated DynamoDB for partition {partition_date}")
                
            except Exception as e:
                errors += 1
                print(f"✗ Error processing record: {str(e)}")
                print(f"  Record: {record}")
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed': processed,
            'errors': errors
        })
    }
```

### Deploy Lambda with MSK Trigger

```bash
# Create Lambda function
aws lambda create-function \
  --function-name chargeback-consolidation-consumer \
  --runtime python3.11 \
  --role arn:aws:iam::123456789:role/lambda-msk-execution-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://function.zip \
  --timeout 60 \
  --memory-size 256 \
  --vpc-config SubnetIds=$PRIVATE_SUBNETS,SecurityGroupIds=$LAMBDA_SG \
  --region sa-east-1

# Create MSK event source mapping
aws lambda create-event-source-mapping \
  --function-name chargeback-consolidation-consumer \
  --event-source-arn arn:aws:kafka:sa-east-1:123456789:cluster/poc-chargeback-dev-chargebacks-cluster/uuid \
  --topics chargeback-consolidation-events \
  --starting-position LATEST \
  --batch-size 100 \
  --maximum-batching-window-in-seconds 10 \
  --region sa-east-1
```

### IAM Policy for Lambda

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:Connect",
        "kafka-cluster:DescribeTopic",
        "kafka-cluster:ReadData"
      ],
      "Resource": [
        "arn:aws:kafka:sa-east-1:*:cluster/*",
        "arn:aws:kafka:sa-east-1:*:topic/*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:UpdateItem",
        "dynamodb:PutItem"
      ],
      "Resource": "arn:aws:dynamodb:sa-east-1:*:table/poc-chargeback-dev-chargebacks"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

### Test the Integration

```bash
# Trigger a consolidation job
aws glue start-job-run \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --region sa-east-1

# Wait for job to complete (~15-20 minutes)

# Check Lambda invocations
aws logs tail /aws/lambda/chargeback-consolidation-consumer \
  --follow \
  --region sa-east-1

# Verify DynamoDB was updated
aws dynamodb get-item \
  --table-name poc-chargeback-dev-chargebacks \
  --key '{"partition_date": {"S": "2025-11-03"}}' \
  --region sa-east-1
```

### Benefits of Kafka Integration

1. **Real-time Updates**: DynamoDB status updated within seconds of consolidation
2. **Decoupled Architecture**: Glue and Lambda operate independently
3. **Scalable**: Can add multiple consumers for different purposes
4. **Audit Trail**: All consolidation events logged in Kafka
5. **Retry Logic**: MSK handles message delivery guarantees
6. **Fan-out**: Single event can trigger multiple downstream processes

## �📚 Additional Resources

### AWS Documentation
- [AWS Glue Developer Guide](https://docs.aws.amazon.com/glue/)
- [AWS Glue Best Practices](https://docs.aws.amazon.com/glue/latest/dg/best-practices.html)
- [EventBridge Scheduler Guide](https://docs.aws.amazon.com/scheduler/latest/UserGuide/)
- [Apache Spark SQL Reference](https://spark.apache.org/docs/latest/sql-programming-guide.html)

### Performance Tuning
- [Optimizing AWS Glue for Apache Spark](https://docs.aws.amazon.com/glue/latest/dg/monitor-profile-glue-job-cloudwatch-metrics.html)
- [Parquet File Format Specification](https://parquet.apache.org/docs/)
- [S3 Performance Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance.html)

### Cost Optimization
- [AWS Glue Pricing](https://aws.amazon.com/glue/pricing/)
- [S3 Storage Classes](https://aws.amazon.com/s3/storage-classes/)
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)

## 🎯 Next Steps

After Phase 4 is deployed and running:

### Immediate (Week 1):
1. ✅ Monitor first few consolidation runs
2. ✅ Verify data quality in consolidated files
3. ✅ Tune worker count based on actual execution time
4. ✅ Set up email alerts for failures

### Short-term (Month 1):
1. Enable landing zone cleanup after verifying consolidation works
2. Analyze query performance improvements
3. Adjust execution frequency based on business needs
4. Document data lineage and processing SLAs

### Long-term (Quarter 1):
1. Implement Athena integration for ad-hoc queries
2. Build BI dashboards (QuickSight, Tableau, etc.)
3. Set up data quality checks and validation
4. Consider advanced features:
   - Incremental processing
   - Change data capture (CDC)
   - Real-time streaming consolidation
   - Data versioning and time travel

---

## 📝 Summary

Phase 4 provides **production-ready data consolidation** with **flexible output formats** and **event-driven architecture**:

✅ **Automated**: EventBridge Scheduler triggers jobs N times/day  
✅ **Flexible**: CSV, Parquet, or JSON output (parametrized)  
✅ **Event-Driven**: Kafka integration for real-time DynamoDB updates  
✅ **Scalable**: Handles 5M+ chargebacks/day with parametrized workers  
✅ **Optimized**: 10-1000x file reduction, 10x faster queries  
✅ **Monitored**: Complete observability with CloudWatch  
✅ **Cost-Efficient**: ~$45/month with intelligent lifecycle policies  
✅ **Maintainable**: Infrastructure as Code, versioned scripts  

**Key Features:**
- 📄 **CSV Output**: Human-readable files for operational use
- 📊 **Parquet Alternative**: Optimized for analytics workloads
- 📨 **Kafka Events**: Real-time consolidation notifications
- 🔄 **DynamoDB Integration**: Lambda consumer for status updates
- 🔐 **IAM Authentication**: Secure MSK access via AWS_MSK_IAM
- 🌐 **VPC Connectivity**: Glue connection for MSK communication

**Estimated Monthly Cost**: ~$45.40  
**Estimated Processing Time**: 15-20 minutes per execution  
**Estimated File Reduction**: 250x fewer files  
**Estimated Query Speedup**: 10x faster  
**Kafka Event Latency**: < 1 second  

---

**Ready to consolidate?** Deploy Phase 4, monitor the first runs, and enjoy optimized analytics with event-driven updates! 🚀

## 🔄 Version History

- **v2.0.0** (Nov 3, 2025): Added CSV output support and Kafka integration
- **v1.0.0** (Oct 23, 2025): Initial Phase 4 implementation with Parquet consolidation

