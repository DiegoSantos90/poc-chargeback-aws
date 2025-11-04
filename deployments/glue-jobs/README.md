# AWS Glue ETL Jobs

This directory contains AWS Glue ETL job scripts for Phase 4 data consolidation.

## 📄 Scripts

### `consolidate_chargebacks.py`

**Purpose**: Consolidates thousands of small Parquet files from Phase 3 Flink output into optimized, partitioned datasets for analytics.

**Runtime**: AWS Glue 3.0 (Spark 3.1, Python 3.7)

**Processing Logic**:
1. Reads landing zone Parquet files via Glue Data Catalog
2. Applies partition filtering (year/month/day)
3. Performs data quality checks (nulls, duplicates)
4. Deduplicates by chargeback_id (keeps latest)
5. Repartitions to N files (parametrized)
6. Writes consolidated Parquet with compression
7. Logs metrics to CloudWatch

**Input**:
- Source: `s3://bucket/landing/chargebacks/YYYY/MM/DD/*.parquet`
- Format: Parquet (small files, 50-100 KB each)
- Volume: ~1.25M records per execution (5M/day ÷ 4 executions)

**Output**:
- Destination: `s3://bucket/consolidated/chargebacks/year=YYYY/month=MM/day=DD/*.parquet`
- Format: Parquet with Snappy compression
- Files: 10 consolidated files (parametrized)
- Size: ~50-100 MB per file

## 🔧 Configuration

The script receives configuration via Glue job arguments:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `SOURCE_DATABASE` | Yes | - | Glue database name |
| `SOURCE_TABLE` | Yes | - | Landing zone table name |
| `OUTPUT_PATH` | Yes | - | S3 path for consolidated files |
| `OUTPUT_FILE_COUNT` | Yes | - | Number of output files |
| `COMPRESSION_CODEC` | Yes | - | Parquet compression (snappy, gzip, etc.) |
| `EXECUTION_TIME` | No | Current UTC time | Job execution timestamp |
| `EXECUTION_SEQUENCE` | No | 1 | Execution number (1 of 4, 2 of 4, etc.) |
| `TOTAL_EXECUTIONS` | No | 4 | Total executions per day |
| `ENABLE_PARTITION_FILTER` | No | true | Enable date partition filtering |
| `PARTITION_DATE` | No | Yesterday | Date to process (YYYY-MM-DD) |
| `DRY_RUN` | No | false | Dry run mode (no writes) |

## 📊 Performance

**Tested Configuration** (5M chargebacks/day, 4 executions):
- Worker Type: G.1X (4 vCPU, 16 GB RAM)
- Number of Workers: 10
- Records per Execution: ~1.25M
- Execution Time: 15-20 minutes
- Output Files: 10 files × ~100 MB each

**Scalability**:
- 10M records/day: Increase to 20 workers
- Real-time (hourly): Increase to 24 executions/day
- Larger files: Decrease OUTPUT_FILE_COUNT

## 🚀 Deployment

The script is automatically uploaded to S3 by Terraform:

```bash
cd infrastructure/terraform/phases/phase-4
terraform apply
```

This will:
1. Upload script to `s3://bucket/glue-scripts/consolidate_chargebacks.py`
2. Create Glue job referencing the script
3. Configure EventBridge schedulers to trigger the job

## 🧪 Testing

### Manual Trigger (AWS CLI)

```bash
# Start job with default arguments (processes yesterday's data)
aws glue start-job-run \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --region sa-east-1

# Start job for specific date
aws glue start-job-run \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --region sa-east-1 \
  --arguments '{
    "--PARTITION_DATE":"2025-11-02",
    "--OUTPUT_FILE_COUNT":"5"
  }'

# Dry run (no output written)
aws glue start-job-run \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --region sa-east-1 \
  --arguments '{"--DRY_RUN":"true"}'
```

### View Logs

```bash
# Tail job logs in real-time
aws logs tail /aws-glue/jobs/poc-chargeback-dev-chargebacks-consolidation \
  --follow \
  --region sa-east-1

# Get recent job runs
aws glue get-job-runs \
  --job-name poc-chargeback-dev-chargebacks-consolidation \
  --region sa-east-1 \
  --max-results 10
```

## 📈 Monitoring

The script logs detailed metrics that can be parsed by CloudWatch Logs Insights:

```
METRICS: records_processed=1250000, duplicates_removed=1250, output_files=10, duration_seconds=1020.45
```

**CloudWatch Logs Insights Query**:

```
fields @timestamp, @message
| filter @message like /METRICS:/
| parse @message "records_processed=*, duplicates_removed=*, output_files=*, duration_seconds=*" 
    as records, duplicates, files, duration
| stats 
    sum(records) as total_records,
    sum(duplicates) as total_duplicates,
    avg(duration) as avg_duration,
    min(duration) as min_duration,
    max(duration) as max_duration
  by bin(5m)
```

## 🐛 Troubleshooting

### Issue: No data found for partition

**Cause**: Landing zone doesn't have data for the specified date

**Solution**:
- Check if Phase 3 Flink is writing data
- Verify Glue Crawler has run and discovered partitions
- Check partition filter in job arguments

### Issue: Job times out

**Cause**: Too much data for current worker configuration

**Solution**:
- Increase `number_of_workers` in Terraform
- Use larger worker type (G.2X or G.4X)
- Process smaller time windows

### Issue: Output file count doesn't match expected

**Cause**: Spark adaptive execution coalescing partitions

**Solution**:
- Disable adaptive coalescing: `spark.sql.adaptive.coalescePartitions.enabled = false`
- Or accept minor variance (Spark optimizes automatically)

### Issue: Duplicates not removed

**Cause**: Multiple records with same chargeback_id but missing updated_at

**Solution**:
- Ensure updated_at is populated in source data
- Modify deduplication logic to use event_timestamp as fallback

## 📚 References

- [AWS Glue Documentation](https://docs.aws.amazon.com/glue/)
- [PySpark SQL Reference](https://spark.apache.org/docs/latest/api/python/reference/pyspark.sql/)
- [Parquet Format Specification](https://parquet.apache.org/docs/)

---

**Last Updated**: November 3, 2025  
**Version**: 1.0.0
