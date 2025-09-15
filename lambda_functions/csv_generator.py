import json
import boto3
import csv
import io
import logging
from datetime import datetime
from typing import Dict, Any, List

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda function to generate CSV files from processed chargeback data
    Ensures maximum of 4 CSV files per batch
    """
    try:
        logger.info(f"Generating CSV files for event: {json.dumps(event)}")
        
        # Extract parameters from event
        bucket = event.get('bucket')
        source_key = event.get('key')
        max_files = event.get('max_files', 4)
        
        if not bucket or not source_key:
            raise ValueError("Missing required parameters: bucket and key")
        
        # Get source data
        response = s3_client.get_object(Bucket=bucket, Key=source_key)
        source_data = json.loads(response['Body'].read().decode('utf-8'))
        
        # Process data and create CSV files
        csv_files = generate_csv_files(source_data, max_files)
        
        # Upload CSV files to processed bucket
        output_bucket = event.get('output_bucket', bucket)
        uploaded_files = []
        
        for i, csv_content in enumerate(csv_files, 1):
            # Generate unique filename
            timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
            csv_key = f"processed/chargeback_batch_{timestamp}_{i:02d}.csv"
            
            # Upload to S3
            s3_client.put_object(
                Bucket=output_bucket,
                Key=csv_key,
                Body=csv_content,
                ContentType='text/csv'
            )
            
            uploaded_files.append({
                'bucket': output_bucket,
                'key': csv_key,
                'size': len(csv_content)
            })
            
            logger.info(f"Generated CSV file: s3://{output_bucket}/{csv_key}")
        
        result = {
            'statusCode': 200,
            'generated_files': uploaded_files,
            'total_files': len(uploaded_files),
            'source_file': f"s3://{bucket}/{source_key}"
        }
        
        logger.info(f"CSV generation completed: {len(uploaded_files)} files created")
        return result
        
    except Exception as e:
        logger.error(f"Error generating CSV files: {str(e)}")
        return {
            'statusCode': 500,
            'error': str(e)
        }

def generate_csv_files(data: List[Dict], max_files: int = 4) -> List[str]:
    """
    Generate CSV files from data, ensuring maximum file limit
    """
    if not data:
        return []
    
    # Calculate records per file
    total_records = len(data)
    records_per_file = (total_records + max_files - 1) // max_files
    
    csv_files = []
    
    for i in range(0, total_records, records_per_file):
        batch_data = data[i:i + records_per_file]
        
        # Create CSV content
        output = io.StringIO()
        if batch_data:
            fieldnames = batch_data[0].keys()
            writer = csv.DictWriter(output, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(batch_data)
        
        csv_content = output.getvalue()
        csv_files.append(csv_content)
        
        # Stop if we reach max files
        if len(csv_files) >= max_files:
            break
    
    return csv_files