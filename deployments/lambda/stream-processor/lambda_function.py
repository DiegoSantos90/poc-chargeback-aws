"""
Lambda Stream Processor - DynamoDB Streams to MSK Kafka
========================================================

This Lambda function:
1. Reads events from DynamoDB Streams
2. Transforms the event data
3. Publishes messages to MSK Kafka topic using IAM authentication

Author: POC Chargeback Team
"""

import json
import logging
import os
from typing import Dict, List, Any
from datetime import datetime

# Environment variables
MSK_BOOTSTRAP_SERVERS = os.environ['MSK_BOOTSTRAP_SERVERS']
KAFKA_TOPIC = os.environ['KAFKA_TOPIC']
AWS_REGION = os.environ['AWS_REGION']
LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')

# Configure logging
logger = logging.getLogger()
logger.setLevel(getattr(logging, LOG_LEVEL))

# Kafka producer (initialized once per Lambda container)
kafka_producer = None


def get_kafka_producer():
    """
    Initialize Kafka producer with MSK IAM authentication.
    This is called once per Lambda container (cold start).
    """
    global kafka_producer
    
    if kafka_producer is None:
        try:
            from kafka import KafkaProducer
            from aws_msk_iam_sasl_signer import MSKAuthTokenProvider
            
            logger.info("Initializing Kafka producer...")
            
            # MSK IAM authentication
            tp = MSKAuthTokenProvider(region=AWS_REGION)
            
            kafka_producer = KafkaProducer(
                bootstrap_servers=MSK_BOOTSTRAP_SERVERS.split(','),
                security_protocol='SASL_SSL',
                sasl_mechanism='OAUTHBEARER',
                sasl_oauth_token_provider=tp,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda k: k.encode('utf-8') if k else None,
                # Producer configuration
                acks='all',  # Wait for all replicas
                retries=3,
                max_in_flight_requests_per_connection=5,
                compression_type='snappy',
                linger_ms=10,  # Batch messages for efficiency
                batch_size=16384,
            )
            
            logger.info("Kafka producer initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Kafka producer: {str(e)}")
            raise
    
    return kafka_producer


def transform_dynamodb_record(record: Dict) -> Dict:
    """
    Transform DynamoDB Stream record to business event format.
    
    Args:
        record: DynamoDB Stream record
        
    Returns:
        Transformed event dictionary
    """
    event_name = record['eventName']  # INSERT, MODIFY, REMOVE
    
    # Extract the new image (current state)
    new_image = record['dynamodb'].get('NewImage', {})
    old_image = record['dynamodb'].get('OldImage', {})
    
    # Transform DynamoDB format to simple dict
    def dynamodb_to_dict(ddb_item):
        """Convert DynamoDB format to Python dict"""
        result = {}
        for key, value in ddb_item.items():
            # Get the actual value from DynamoDB type wrapper
            if 'S' in value:
                result[key] = value['S']
            elif 'N' in value:
                result[key] = float(value['N']) if '.' in value['N'] else int(value['N'])
            elif 'BOOL' in value:
                result[key] = value['BOOL']
            elif 'NULL' in value:
                result[key] = None
            elif 'M' in value:
                result[key] = dynamodb_to_dict(value['M'])
            elif 'L' in value:
                result[key] = [dynamodb_to_dict({'item': item})['item'] for item in value['L']]
        return result
    
    # Build the event
    event = {
        'event_type': event_name,
        'event_timestamp': datetime.utcnow().isoformat(),
        'table_name': record['eventSourceARN'].split('/')[-3],
        'event_id': record['eventID'],
        'data': dynamodb_to_dict(new_image) if new_image else None,
        'old_data': dynamodb_to_dict(old_image) if old_image and event_name == 'MODIFY' else None,
    }
    
    return event


def lambda_handler(event: Dict, context: Any) -> Dict:
    """
    Lambda handler function.
    
    Args:
        event: DynamoDB Stream event
        context: Lambda context
        
    Returns:
        Response with success/failure counts
    """
    logger.info(f"Processing {len(event['Records'])} DynamoDB Stream records")
    
    producer = get_kafka_producer()
    
    success_count = 0
    failure_count = 0
    failures = []
    
    for record in event['Records']:
        try:
            # Transform DynamoDB record
            transformed_event = transform_dynamodb_record(record)
            
            # Extract key for Kafka partitioning (chargeback_id)
            key = transformed_event['data'].get('chargeback_id') if transformed_event['data'] else None
            
            # Send to Kafka
            future = producer.send(
                topic=KAFKA_TOPIC,
                key=key,
                value=transformed_event,
            )
            
            # Wait for confirmation (with timeout)
            result = future.get(timeout=10)
            
            logger.debug(
                f"Sent message to Kafka: topic={result.topic}, "
                f"partition={result.partition}, offset={result.offset}"
            )
            
            success_count += 1
            
        except Exception as e:
            logger.error(f"Failed to process record: {str(e)}", exc_info=True)
            failure_count += 1
            failures.append({
                'record_id': record.get('eventID'),
                'error': str(e)
            })
    
    # Flush producer to ensure all messages are sent
    producer.flush(timeout=30)
    
    response = {
        'statusCode': 200 if failure_count == 0 else 207,  # 207 = Multi-Status
        'body': {
            'processed': len(event['Records']),
            'succeeded': success_count,
            'failed': failure_count,
            'failures': failures[:10]  # Limit to first 10 failures
        }
    }
    
    if failure_count > 0:
        logger.warning(f"Processed with errors: {success_count} succeeded, {failure_count} failed")
        # Raise exception to trigger Lambda retry for failed records
        # DynamoDB Streams will retry failed batches
        raise Exception(f"Failed to process {failure_count} records")
    else:
        logger.info(f"Successfully processed all {success_count} records")
    
    return response


# For local testing
if __name__ == "__main__":
    # Sample test event
    test_event = {
        "Records": [
            {
                "eventID": "1",
                "eventName": "INSERT",
                "eventVersion": "1.1",
                "eventSource": "aws:dynamodb",
                "awsRegion": "us-east-1",
                "dynamodb": {
                    "Keys": {
                        "chargeback_id": {"S": "cb_test_123"}
                    },
                    "NewImage": {
                        "chargeback_id": {"S": "cb_test_123"},
                        "merchant_id": {"S": "merch_456"},
                        "amount": {"N": "150.00"},
                        "status": {"S": "pending"},
                        "created_at": {"S": "2025-10-22T10:00:00Z"}
                    },
                    "SequenceNumber": "111",
                    "SizeBytes": 26,
                    "StreamViewType": "NEW_AND_OLD_IMAGES"
                },
                "eventSourceARN": "arn:aws:dynamodb:us-east-1:123456789:table/chargebacks/stream/2025-10-22T00:00:00.000"
            }
        ]
    }
    
    # Mock context
    class MockContext:
        function_name = "test-function"
        memory_limit_in_mb = 512
        invoked_function_arn = "arn:aws:lambda:us-east-1:123456789:function:test"
        aws_request_id = "test-request-id"
    
    print(lambda_handler(test_event, MockContext()))
