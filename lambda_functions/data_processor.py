import json
import boto3
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda function to process incoming chargeback data
    Validates data format and initiates processing workflow
    """
    try:
        logger.info(f"Processing event: {json.dumps(event)}")
        
        # Parse S3 event
        for record in event.get('Records', []):
            if record.get('eventSource') == 'aws:s3':
                bucket = record['s3']['bucket']['name']
                key = record['s3']['object']['key']
                
                logger.info(f"Processing file: s3://{bucket}/{key}")
                
                # Validate file format
                if not key.endswith(('.json', '.csv', '.txt')):
                    logger.warning(f"Unsupported file format: {key}")
                    continue
                
                # Get file content
                response = s3_client.get_object(Bucket=bucket, Key=key)
                content = response['Body'].read()
                
                # Basic validation
                if len(content) == 0:
                    logger.warning(f"Empty file detected: {key}")
                    continue
                
                # Create processing message
                processing_data = {
                    'bucket': bucket,
                    'key': key,
                    'size': len(content),
                    'timestamp': datetime.utcnow().isoformat(),
                    'status': 'pending'
                }
                
                # Send to processing queue (would be configured via environment)
                # This is a placeholder for the actual SQS queue URL
                logger.info(f"File validated successfully: {key}")
                
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Files processed successfully',
                'processed_files': len(event.get('Records', []))
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing data: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }