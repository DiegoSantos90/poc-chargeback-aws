# 📋 QUICK SUMMARY: Created Resources IDs

**Deploy Date**: 14/10/2025  
**AWS Region**: sa-east-1 (São Paulo)  
**Total Resources**: 31

---

## 🆔 MAIN RESOURCES IDS

### 🌐 VPC and Network
| Resource | Name/ID | Type |
|----------|---------|------|
| **VPC** | `vpc-06ec1227938c27384` | poc-chargeback-vpc |
| **Internet Gateway** | `igw-04ed6f1389bd37a00` | poc-chargeback-igw |
| **NAT Gateway 1** | `nat-0d76e2ba8cfd4be14` | poc-chargeback-nat-gateway-1 |
| **NAT Gateway 2** | `nat-07e2407ff54fc3c58` | poc-chargeback-nat-gateway-2 |

### 🏠 Subnets
| Subnet | ID | CIDR | Zone |
|--------|----|------|------|
| **Public 1** | `subnet-05005958aa5583c39` | 10.0.0.0/24 | sa-east-1a |
| **Public 2** | `subnet-0b7766834f72467aa` | 10.0.1.0/24 | sa-east-1b |
| **Private 1** | `subnet-0089ed35261719956` | 10.0.10.0/24 | sa-east-1a |
| **Private 2** | `subnet-0845f7b410e4b1967` | 10.0.11.0/24 | sa-east-1b |

### 📊 Database
| Resource | Name/ARN |
|----------|----------|
| **DynamoDB Table** | `chargebacks` |
| **DynamoDB Stream** | `arn:aws:dynamodb:sa-east-1:730323515494:table/chargebacks/stream/2025-10-14T00:26:54.686` |

### 🗄️ Storage
| Resource | Name |
|----------|------|
| **S3 Parquet** | `poc-chargeback-parquet-files-dev` |
| **S3 CSV** | `poc-chargeback-csv-files-dev` |

### 🔒 Security
| Resource | ID |
|----------|---|
| **Security Group** | `sg-07bca843ab83111ea` |

---

## 🔍 QUICK CONSOLE SEARCH COMMANDS

### Search VPC:
- VPC Console → Your VPCs → Search: `vpc-06ec1227938c27384`

### Search DynamoDB:
- DynamoDB Console → Tables → Search: `chargebacks`

### Search S3:
- S3 Console → Buckets → Search: `poc-chargeback-parquet-files-dev`

### Search Security Group:
- EC2 Console → Security Groups → Search: `sg-07bca843ab83111ea`

---

## 💰 ESTIMATED COSTS

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| NAT Gateway 1 | ~$45.00 |
| NAT Gateway 2 | ~$45.00 |
| DynamoDB | Pay-per-request (~$0-5) |
| S3 Storage | Pay-per-use (~$0-1) |
| **TOTAL** | **~$90-95/month** |

---

## ⚡ EXPRESS VALIDATION (5 minutes)

1. **VPC**: https://sa-east-1.console.aws.amazon.com/vpc/home?region=sa-east-1#vpcs:VpcId=vpc-06ec1227938c27384
2. **DynamoDB**: https://sa-east-1.console.aws.amazon.com/dynamodbv2/home?region=sa-east-1#table?name=chargebacks
3. **S3 Parquet**: https://s3.console.aws.amazon.com/s3/buckets/poc-chargeback-parquet-files-dev?region=sa-east-1
4. **S3 CSV**: https://s3.console.aws.amazon.com/s3/buckets/poc-chargeback-csv-files-dev?region=sa-east-1

---

## 🧪 TEST COMMANDS

### Test DynamoDB via CLI:
```bash
aws dynamodb scan --table-name chargebacks --region sa-east-1
```

### Test S3 via CLI:
```bash
aws s3 ls s3://poc-chargeback-parquet-files-dev --region sa-east-1
aws s3 ls s3://poc-chargeback-csv-files-dev --region sa-east-1
```

### View Terraform outputs:
```bash
cd infrastructure/terraform
terraform output
```

---

## 🗑️ QUICK CLEANUP

If you need to destroy everything:
```bash
./scripts/destroy-phase1.sh
```

**⚠️ WARNING**: This will remove ALL resources and data!