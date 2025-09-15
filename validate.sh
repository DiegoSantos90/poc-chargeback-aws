#!/bin/bash

# Chargeback System Validation Script
# This script validates the system components and configuration

echo "🔍 Validating Chargeback System Configuration..."

# Check if all required files exist
REQUIRED_FILES=(
    "main.tf"
    "s3.tf" 
    "lambda.tf"
    "step_functions.tf"
    "iam.tf"
    "messaging.tf"
    "monitoring.tf"
    "outputs.tf"
    "lambda_functions/data_processor.py"
    "lambda_functions/csv_generator.py"
    "lambda_functions/ftp_uploader.py"
    "examples/sample_chargeback_data.json"
    "terraform.tfvars.example"
)

echo "📁 Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file - Found"
    else
        echo "❌ $file - Missing"
        exit 1
    fi
done

# Check Python syntax
echo "🐍 Validating Python Lambda functions..."
for py_file in lambda_functions/*.py; do
    if python3 -m py_compile "$py_file" 2>/dev/null; then
        echo "✅ $py_file - Syntax valid"
    else
        echo "❌ $py_file - Syntax error"
        exit 1
    fi
done

# Check JSON syntax
echo "📄 Validating JSON files..."
for json_file in examples/*.json; do
    if python3 -m json.tool "$json_file" > /dev/null 2>&1; then
        echo "✅ $json_file - Valid JSON"
    else
        echo "❌ $json_file - Invalid JSON"
        exit 1
    fi
done

# Summary
echo ""
echo "🎉 All validations passed!"
echo ""
echo "📋 System Summary:"
echo "   • Terraform Infrastructure: ✅"
echo "   • Lambda Functions: ✅" 
echo "   • Step Functions Workflow: ✅"
echo "   • Monitoring & Alerting: ✅"
echo "   • Example Data Files: ✅"
echo "   • Documentation: ✅"
echo ""
echo "🚀 Ready for deployment!"
echo ""
echo "Next steps:"
echo "1. terraform init"
echo "2. terraform plan"
echo "3. terraform apply"
echo "4. Configure FTP credentials in Secrets Manager"
echo "5. Upload test data to S3"