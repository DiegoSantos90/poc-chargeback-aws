# Flink Application JAR

## 📦 How to add your Flink JAR

1. **Build your Flink application** in a separate repository:
   ```bash
   cd /path/to/chargeback-flink-app
   mvn clean package
   ```

2. **Copy the JAR here**:
   ```bash
   cp target/chargeback-parquet-writer-1.0-SNAPSHOT.jar \
      /path/to/poc-chargeback-aws/deployments/flink/chargeback-parquet-writer.jar
   ```

3. **Terraform will automatically upload** on next apply:
   ```bash
   cd infrastructure/terraform
   terraform apply
   ```

## � S3 Structure

The JAR will be uploaded to a **separate directory** in the Parquet bucket:

```
s3://poc-chargeback-{env}-parquet/
├── artifacts/                        # 🔧 Application artifacts (isolated)
│   └── flink/
│       └── applications/
│           └── flink-parquet-writer/
│               └── application.jar   # Your Flink JAR here
│
├── flink-state/                      # 💾 Flink runtime state
│   └── checkpoints/
│       └── flink-parquet-writer/
│           └── chk-*/
│
└── landing/                          # 📊 Business data (Parquet files)
    └── chargebacks/
        └── YYYY/MM/DD/
            └── *.parquet
```

**Separation of concerns:**
- `artifacts/` - Application binaries (JARs, dependencies)
- `flink-state/` - Runtime checkpoints and savepoints
- `landing/` - Business data output (Parquet files)

This ensures your JAR artifacts are **completely isolated** from business data.

## �📝 Expected JAR name

The Terraform expects this file:
- `chargeback-parquet-writer.jar`

You can change this in `infrastructure/terraform/phases/phase-3/s3-artifacts.tf`

## 🔄 JAR Versioning

The S3 object will be updated whenever the JAR file changes (based on file hash).
Flink application will need to be restarted to pick up the new version.

## 🚫 .gitignore

JAR files are ignored by git (they're binary and large).
Each developer/CI should build and place their own JAR here.
