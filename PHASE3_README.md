# Phase 3: MSK Streaming + Flink Processing - Implementation Guide

## 📋 Overview

Phase 3 implements a real-time streaming pipeline that captures database changes and processes them through Apache Kafka (MSK) and Apache Flink. This phase focuses on **change data capture (CDC)** and **streaming analytics**.

## 🎯 Phase 3 Objectives

- ✅ **DynamoDB Streams**: Capture all database changes in real-time
- ✅ **Lambda Stream Processor**: Forward changes to Kafka (Python 3)
- ✅ **MSK Serverless**: Kafka cluster with auto-scaling and IAM authentication
- ✅ **Apache Flink**: Process events 1:1 and write Parquet files
- ✅ **S3 Landing Zone**: Store individual Parquet files for downstream processing
- ✅ **Monitoring**: CloudWatch logs, metrics, and alarms

## 🏗️ Phase 3 Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         AWS VPC                                  │
│                                                                  │
│  ┌─────────────┐                                                │
│  │  DynamoDB   │                                                │
│  │ (chargebacks)│                                               │
│  └──────┬──────┘                                                │
│         │ DynamoDB Streams                                      │
│         ▼                                                        │
│  ┌──────────────────┐                                          │
│  │ Lambda (Python)  │                                          │
│  │ Stream Processor │                                          │
│  │ - Read Streams   │                                          │
│  │ - Transform      │                                          │
│  │ - Publish Kafka  │                                          │
│  └──────┬───────────┘                                          │
│         │ IAM Auth                                              │
│         ▼                                                        │
│  ┌──────────────────┐                                          │
│  │  MSK Serverless  │                                          │
│  │ Topic: chargebacks│                                         │
│  │ - Auto-scaling   │                                          │
│  │ - IAM Auth       │                                          │
│  │ - 3 Partitions   │                                          │
│  └──────┬───────────┘                                          │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────┐                                          │
│  │ Kinesis Analytics│                                          │
│  │ (Flink 1.15)     │                                          │
│  │ - Consume Kafka  │                                          │
│  │ - Process 1:1    │                                          │
│  │ - Write Parquet  │                                          │
│  └──────┬───────────┘                                          │
└─────────│────────────────────────────────────────────────────┘
          │
          ▼
    ┌─────────────────┐
    │  S3 Parquet     │
    │  Landing Zone   │
    │                 │
    │ /landing/       │
    │   YYYY-MM-DD/   │
    │     HH/         │
    │       file.parq │
    └─────────────────┘
```

## 📁 Project Structure

```
infrastructure/terraform/phases/phase-3/
├── variables.tf              # Configuration variables
├── data-sources.tf            # Phase 1 imports
├── msk.tf                     # MSK Serverless cluster
├── iam.tf                     # IAM roles and policies
├── lambda-stream-processor.tf # Python Lambda function
├── kinesis-analytics.tf       # Flink application
├── cloudwatch.tf              # Monitoring and alarms
└── outputs.tf                 # Exported values

deployments/lambda/stream-processor/
├── lambda_function.py         # Python Lambda code
├── requirements.txt           # Python dependencies
└── README.md                  # Lambda documentation
```

## 🚀 Deployment Guide

### Prerequisites

1. **Phase 1 deployed**: VPC, DynamoDB, S3 buckets
2. **Python 3.11+**: For Lambda development
3. **Java 11+**: For Flink application (if building custom JAR)
4. **Maven or Gradle**: For building Flink application

### Step 1: Deploy Infrastructure

```bash
cd infrastructure/terraform

# Review what will be created
terraform plan

# Deploy Phase 3
terraform apply
```

**Resources Created:**
- 1× MSK Serverless cluster
- 1× Lambda function (Python 3.11)
- 1× Kinesis Data Analytics application
- 3× Security groups
- 2× IAM roles with policies
- 3× CloudWatch log groups
- 1× CloudWatch dashboard
- 5+ CloudWatch alarms
- 1× SQS Dead Letter Queue (optional)

### Step 2: Create Kafka Topic

MSK Serverless doesn't support automatic topic creation via Terraform. Create manually:

**Option A: Using AWS CLI + kafka-topics.sh**

```bash
# Get MSK bootstrap servers
BOOTSTRAP=$(terraform output -raw msk_bootstrap_brokers)

# Create client.properties file
cat > client.properties <<EOF
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
EOF

# Create topic (requires Kafka CLI tools installed)
kafka-topics.sh --bootstrap-server $BOOTSTRAP \
  --command-config client.properties \
  --create \
  --topic chargebacks \
  --partitions 3 \
  --replication-factor 3
```

**Option B: Using Lambda (Automated)**

See PHASE3_README.md section "Automated Topic Creation" for Lambda code.

### Step 3: Deploy Lambda Code

```bash
cd deployments/lambda/stream-processor

# Install dependencies
pip install -r requirements.txt -t .

# Create deployment package
zip -r ../stream-processor.zip .

# Re-deploy infrastructure to pick up new package
cd ../../../infrastructure/terraform
terraform apply
```

### Step 4: Build Flink Application

**See "Flink Application Development" section below for complete code.**

```bash
# Clone sample Flink application
git clone https://github.com/your-org/chargeback-flink-app.git
cd chargeback-flink-app

# Build with Maven
mvn clean package

# Upload to S3
aws s3 cp target/chargeback-parquet-writer-1.0.jar \
  s3://$(terraform output -raw parquet_bucket_name)/flink/applications/chargeback-parquet-writer/application.jar
```

### Step 5: Start Flink Application

```bash
# Start via AWS CLI
aws kinesisanalyticsv2 start-application \
  --application-name $(terraform output -raw flink_application_name) \
  --region $(terraform output -raw region)

# Check status
aws kinesisanalyticsv2 describe-application \
  --application-name $(terraform output -raw flink_application_name)
```

## 🐍 Lambda Stream Processor (Python)

The Lambda function code is provided in `deployments/lambda/stream-processor/lambda_function.py`.

### Key Features:

- **DynamoDB Streams Integration**: Automatic polling and checkpointing
- **MSK IAM Authentication**: Secure, credential-free connection
- **Error Handling**: Retries and Dead Letter Queue
- **Batching**: Processes up to 100 records per invocation
- **Monitoring**: CloudWatch logs and metrics

### Testing Locally:

```bash
cd deployments/lambda/stream-processor

# Set environment variables
export MSK_BOOTSTRAP_SERVERS="b-1.xxx.kafka.us-east-1.amazonaws.com:9098"
export KAFKA_TOPIC="chargebacks"
export AWS_REGION="us-east-1"
export LOG_LEVEL="DEBUG"

# Run test
python lambda_function.py
```

## ☕ Flink Application Development

### Minimal Flink Application (Java)

Create a Maven project with this structure:

```
chargeback-flink-app/
├── pom.xml
└── src/main/java/com/yourcompany/
    ├── ChargebackParquetWriter.java
    ├── model/
    │   └── Chargeback.java
    └── serialization/
        └── ChargebackDeserializer.java
```

### pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.yourcompany</groupId>
    <artifactId>chargeback-flink-app</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <flink.version>1.15.4</flink.version>
        <scala.binary.version>2.12</scala.binary.version>
    </properties>

    <dependencies>
        <!-- Flink -->
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-streaming-java</artifactId>
            <version>${flink.version}</version>
            <scope>provided</scope>
        </dependency>

        <!-- Kafka Connector -->
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-connector-kafka</artifactId>
            <version>${flink.version}</version>
        </dependency>

        <!-- Parquet -->
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-parquet</artifactId>
            <version>${flink.version}</version>
        </dependency>

        <!-- AWS MSK IAM Auth -->
        <dependency>
            <groupId>software.amazon.msk</groupId>
            <artifactId>aws-msk-iam-auth</artifactId>
            <version>1.1.6</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.2.4</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

### ChargebackParquetWriter.java (Simplified for 1:1 Processing)

```java
package com.yourcompany;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.core.fs.Path;
import org.apache.flink.formats.parquet.avro.ParquetAvroWriters;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.filesystem.StreamingFileSink;
import org.apache.flink.streaming.api.functions.sink.filesystem.rollingpolicies.DefaultRollingPolicy;

import java.time.Duration;
import java.util.Properties;

public class ChargebackParquetWriter {
    public static void main(String[] args) throws Exception {
        // Environment
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.enableCheckpointing(60000); // 60 seconds

        // Kafka Source with MSK IAM Auth
        Properties kafkaProps = new Properties();
        kafkaProps.setProperty("security.protocol", "SASL_SSL");
        kafkaProps.setProperty("sasl.mechanism", "AWS_MSK_IAM");
        kafkaProps.setProperty("sasl.jaas.config", 
            "software.amazon.msk.auth.iam.IAMLoginModule required;");
        kafkaProps.setProperty("sasl.client.callback.handler.class", 
            "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

        KafkaSource<Chargeback> source = KafkaSource.<Chargeback>builder()
            .setBootstrapServers(System.getenv("KAFKA_BOOTSTRAP_SERVERS"))
            .setTopics("chargebacks")
            .setGroupId("flink-parquet-writer")
            .setValueOnlyDeserializer(new ChargebackDeserializer())
            .setProperties(kafkaProps)
            .setStartingOffsets(OffsetsInitializer.latest())
            .build();

        // Stream Processing (1:1 - no aggregation)
        DataStream<Chargeback> chargebacks = env
            .fromSource(source, WatermarkStrategy.noWatermarks(), "Kafka Source")
            .map(chargeback -> {
                // Simple validation/transformation
                if (chargeback.getAmount() == null) {
                    throw new IllegalArgumentException("Invalid amount");
                }
                return chargeback;
            });

        // Parquet Sink (1 file per record, consolidated by checkpointing)
        String outputPath = String.format("s3://%s/%s",
            System.getenv("S3_BUCKET"),
            System.getenv("S3_PREFIX"));

        StreamingFileSink<Chargeback> sink = StreamingFileSink
            .forBulkFormat(
                new Path(outputPath),
                ParquetAvroWriters.forReflectRecord(Chargeback.class)
            )
            .withRollingPolicy(
                DefaultRollingPolicy.builder()
                    .withRolloverInterval(Duration.ofSeconds(60))
                    .withMaxPartSize(1024 * 1024 * 10) // 10MB
                    .build()
            )
            .withBucketAssigner(new DateTimeBucketAssigner<>("yyyy-MM-dd/HH"))
            .build();

        chargebacks.addSink(sink);

        env.execute("Chargeback Parquet Writer");
    }
}
```

**Note**: This is a simplified example. For production, add proper error handling, metrics, and testing.

## 📊 Monitoring & Observability

### CloudWatch Dashboard

Access the dashboard:
```bash
terraform output cloudwatch_dashboard_url
```

**Widgets Include:**
- Lambda invocations, errors, duration
- MSK connections, throughput
- Flink KPUs, uptime, records/sec
- Recent error logs

### View Logs

```bash
# Lambda logs
aws logs tail $(terraform output -raw lambda_log_group_name) --follow

# Flink logs
aws logs tail $(terraform output -raw flink_log_group_name) --follow
```

### CloudWatch Insights Queries

**Find Lambda Errors:**
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

**Flink Checkpoint Duration:**
```sql
fields @timestamp, checkpointDuration
| filter @message like /Checkpoint/
| stats avg(checkpointDuration) as avgDuration by bin(5m)
```

## 🧪 Testing the Pipeline

### End-to-End Test

1. **Create a chargeback via Phase 2 API:**
```bash
curl -X POST $(terraform output -raw api_gateway_url)/chargebacks \
  -H "Content-Type: application/json" \
  -d '{
    "merchant_id": "merch_test_001",
    "amount": 99.99,
    "currency": "USD",
    "reason": "Product not received"
  }'
```

2. **Watch Lambda process the event:**
```bash
aws logs tail /aws/lambda/poc-chargeback-dev-stream-processor --follow
```

3. **Verify message in Kafka** (requires kafka-console-consumer.sh):
```bash
kafka-console-consumer.sh \
  --bootstrap-server $(terraform output -raw msk_bootstrap_brokers) \
  --topic chargebacks \
  --from-beginning \
  --consumer.config client.properties
```

4. **Check Flink processed it:**
```bash
aws logs tail /aws/kinesisanalytics/poc-chargeback-dev-chargeback-parquet-writer --follow
```

5. **Verify Parquet file in S3:**
```bash
aws s3 ls s3://$(terraform output -raw parquet_bucket_name)/landing/chargebacks/ --recursive
```

## 🔧 Troubleshooting

### Lambda Can't Connect to MSK

**Symptoms:** Connection timeout, `kafka.errors.NoBrokersAvailable`

**Solutions:**
1. Check security groups allow Lambda → MSK (port 9098)
2. Verify Lambda is in private subnets
3. Confirm IAM role has `kafka-cluster:*` permissions
4. Check MSK cluster is running: `aws kafka list-clusters-v2`

### Flink Application Won't Start

**Symptoms:** Application stuck in "STARTING" state

**Solutions:**
1. Verify JAR uploaded to correct S3 path
2. Check IAM role has S3 read permissions
3. Review Flink logs for Java exceptions
4. Ensure VPC configuration is correct

### Parquet Files Not Appearing

**Symptoms:** No files in S3 landing zone

**Solutions:**
1. Check Flink checkpointing is enabled (files written on checkpoint)
2. Verify S3 bucket permissions in IAM role
3. Look for Flink sink errors in CloudWatch
4. Confirm data is flowing through Kafka

### High Lambda Costs

**Symptoms:** Unexpected AWS bills

**Solutions:**
1. Reduce Lambda memory (512MB → 256MB)
2. Increase batch size to process more records per invocation
3. Check for infinite retries (DLQ issues)
4. Monitor invocation count in CloudWatch

## 💰 Cost Optimization

**Phase 3 Estimated Monthly Costs (POC):**

| Service | Configuration | Monthly Cost |
|---------|--------------|-------------|
| MSK Serverless | 1GB/hour throughput | ~$60 |
| Lambda | 512MB, 10K invocations/day | ~$5 |
| Flink (1 KPU) | 24/7 running | ~$80 |
| CloudWatch Logs | 1 day retention | ~$1 |
| **Total** | | **~$146/month** |

**Production Optimizations:**
- Use provisioned MSK if throughput is predictable (~40% cheaper)
- Stop Flink during off-hours if real-time isn't required
- Increase log retention to 7 days for compliance

## 📚 Additional Resources

- [AWS MSK Serverless Documentation](https://docs.aws.amazon.com/msk/latest/developerguide/serverless.html)
- [Kinesis Data Analytics for Flink](https://docs.aws.amazon.com/kinesisanalytics/latest/java/what-is.html)
- [Apache Flink Documentation](https://flink.apache.org/docs/stable/)
- [kafka-python Documentation](https://kafka-python.readthedocs.io/)

## 🚀 Next Steps

After Phase 3 is deployed and validated:

1. **Phase 4**: AWS Glue Job for Parquet consolidation and CSV generation
2. **Phase 5**: EventBridge scheduling and automation
3. **Phase 6**: Monitoring dashboards and alerting
4. **Phase 7**: Production hardening and cost optimization
