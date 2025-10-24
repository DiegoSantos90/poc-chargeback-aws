#!/bin/bash
# ==============================================================================
# Lambda Deployment Package Builder
# ==============================================================================
# This script builds the Lambda deployment package with all dependencies
# and cleans up temporary files after creating the zip.
#
# Usage: ./build.sh
# ==============================================================================

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "Lambda Deployment Package Builder"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Clean existing artifacts
echo -e "${YELLOW}[1/5] Cleaning existing artifacts...${NC}"
if [ -f "../stream-processor.zip" ]; then
    rm -f "../stream-processor.zip"
    echo "  ✓ Removed old stream-processor.zip"
fi

# Step 2: Install dependencies
echo -e "${YELLOW}[2/5] Installing Python dependencies...${NC}"
pip3 install -r requirements.txt -t . --upgrade --quiet
echo "  ✓ Dependencies installed"

# Step 3: Create deployment package
echo -e "${YELLOW}[3/5] Creating deployment package...${NC}"
zip -r ../stream-processor.zip . \
    -x "*.pyc" \
    -x "*__pycache__*" \
    -x "*.dist-info/*" \
    -x "build.sh" \
    -x ".gitignore" \
    > /dev/null 2>&1

ZIP_SIZE=$(ls -lh ../stream-processor.zip | awk '{print $5}')
echo "  ✓ Created stream-processor.zip (${ZIP_SIZE})"

# Step 4: List package contents (first 20 files)
echo -e "${YELLOW}[4/5] Package contents (sample):${NC}"
unzip -l ../stream-processor.zip | head -25 | tail -20

# Step 5: Clean up temporary files
echo -e "${YELLOW}[5/5] Cleaning up temporary files...${NC}"

# Remove Python package directories (force removal even with different permissions)
rm -rf kafka/ 2>/dev/null || true
rm -rf boto3/ 2>/dev/null || true
chmod -R u+w botocore/ 2>/dev/null || true
rm -rf botocore/ 2>/dev/null || true
rm -rf aws_msk_iam_sasl_signer/ 2>/dev/null || true
rm -rf dateutil/ 2>/dev/null || true
rm -rf urllib3/ 2>/dev/null || true
rm -rf s3transfer/ 2>/dev/null || true
rm -rf jmespath/ 2>/dev/null || true
rm -rf click/ 2>/dev/null || true

# Remove .dist-info directories
rm -rf *.dist-info/ 2>/dev/null || true

# Remove standalone Python files from dependencies
rm -f six.py 2>/dev/null || true

# Remove __pycache__ directories
rm -rf __pycache__/ 2>/dev/null || true

# Remove bin directory (pip scripts)
rm -rf bin/ 2>/dev/null || true

echo "  ✓ Temporary files removed"

# Summary
echo ""
echo "=================================================="
echo -e "${GREEN}✓ Build completed successfully!${NC}"
echo "=================================================="
echo ""
echo "Deployment package: ../stream-processor.zip"
echo "Size: ${ZIP_SIZE}"
echo ""
echo "Next steps:"
echo "  1. cd ../../infrastructure/terraform"
echo "  2. terraform apply phase3.tfplan"
echo ""
