#!/bin/bash

set -e

echo "==========================================="
echo "Building Lambda Consolidation Updater"
echo "==========================================="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf package
rm -f consolidation-updater.zip
rm -f ../consolidation-updater.zip

# Create package directory
echo "Creating package directory..."
mkdir -p package

# Install dependencies (if any beyond boto3)
if [ -f requirements.txt ]; then
    echo "Installing Python dependencies..."
    pip install -r requirements.txt -t package/ --upgrade
else
    echo "No requirements.txt found, skipping dependency installation"
fi

# Copy Lambda function code
echo "Copying Lambda function code..."
cp lambda_function.py package/

# Create deployment package
echo "Creating deployment ZIP..."
cd package
zip -r ../consolidation-updater.zip . -q
cd ..

# Copy to parent lambda directory for Terraform
echo "Copying to deployment directory..."
cp consolidation-updater.zip ../

# Calculate checksum
echo "Calculating SHA256 checksum..."
if command -v sha256sum &> /dev/null; then
    sha256sum consolidation-updater.zip > consolidation-updater.zip.sha256
elif command -v shasum &> /dev/null; then
    shasum -a 256 consolidation-updater.zip > consolidation-updater.zip.sha256
else
    echo "Warning: Could not calculate checksum (sha256sum/shasum not found)"
fi

# Get file size
FILE_SIZE=$(ls -lh consolidation-updater.zip | awk '{print $5}')

echo "==========================================="
echo "Build complete!"
echo "Package: consolidation-updater.zip"
echo "Size: $FILE_SIZE"
echo "==========================================="

# Optional: Upload to S3 (uncomment if needed)
# BUCKET_NAME=${S3_BUCKET:-"your-lambda-artifacts-bucket"}
# aws s3 cp consolidation-updater.zip s3://$BUCKET_NAME/lambda/consolidation-updater/consolidation-updater.zip
# echo "Uploaded to s3://$BUCKET_NAME/lambda/consolidation-updater/consolidation-updater.zip"
