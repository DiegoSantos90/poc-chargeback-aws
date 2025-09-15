# Chargeback System - System Design Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CHARGEBACK PROCESSING SYSTEM                        │
│                                   (AWS Services)                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Raw Data      │    │  Processed CSV  │    │  Failed Files   │
│   S3 Bucket     │    │   S3 Bucket     │    │   S3 Bucket     │
│ (incoming data) │    │ (output files)  │    │ (error files)   │
└─────────┬───────┘    └─────────────────┘    └─────────────────┘
          │
          │ S3 Event Trigger
          ▼
┌─────────────────┐
│ Step Functions  │ ◄─── Workflow Orchestration
│   State Machine │
└─────────┬───────┘
          │
          │ Invoke Lambda Functions
          ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Data Processor  │    │  CSV Generator  │    │  FTP Uploader   │
│    Lambda       │───▶│     Lambda      │───▶│     Lambda      │
│ (validate data) │    │ (max 4 CSVs)    │    │ (send to FTP)   │
└─────────────────┘    └─────────────────┘    └─────────┬───────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│      SQS        │    │   SNS Topics    │    │ Secrets Manager │
│ Processing Queue│    │ (notifications) │    │ (FTP credentials│
│ + Dead Letter Q │    │   + Alerts      │    │    storage)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                            MONITORING & LOGGING                                  │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│   CloudWatch    │   CloudWatch    │   CloudWatch    │       X-Ray             │
│     Logs        │    Metrics      │   Dashboard     │   (Distributed Tracing) │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘

                              ┌─────────────────┐
                              │  External FTP   │
                              │  Card Company   │
                              │    Servers      │
                              └─────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                                DATA FLOW                                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│ 1. Raw chargeback data uploaded to S3 (incoming/ prefix)                        │
│ 2. S3 event triggers Step Functions workflow                                    │
│ 3. Data Processor Lambda validates and processes input data                     │
│ 4. CSV Generator Lambda creates up to 4 CSV files from processed data          │
│ 5. FTP Uploader Lambda sends CSV files to card company FTP servers             │
│ 6. Success/failure notifications sent via SNS                                   │
│ 7. All activities logged to CloudWatch for monitoring                           │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              KEY FEATURES                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│ • Maximum 4 CSV files per processing batch                                      │
│ • Serverless architecture with automatic scaling                                │
│ • Built-in error handling and retry mechanisms                                  │
│ • Secure credential management with AWS Secrets Manager                         │
│ • Comprehensive monitoring with CloudWatch                                      │
│ • Cost-effective pay-per-use model                                             │
│ • Encrypted data storage and transmission                                       │
└─────────────────────────────────────────────────────────────────────────────────┘
```