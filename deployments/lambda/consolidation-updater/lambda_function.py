"""
Lambda function to process Kafka consolidation events and update DynamoDB.

This function consumes events from the MSK Kafka topic 'chargeback-consolidation-events'
and updates DynamoDB chargeback records with consolidation metadata.

Event Flow:
    MSK Kafka → Lambda → DynamoDB Update

Author: AWS POC Chargeback Team
"""

import json
import os
import base64
from datetime import datetime
from typing import Dict, List, Any, Optional
import logging

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger.setLevel(getattr(logging, log_level))

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('AWS_REGION', 'sa-east-1'))
cloudwatch = boto3.client('cloudwatch', region_name=os.environ.get('AWS_REGION', 'sa-east-1'))

# Get table name from environment
TABLE_NAME = os.environ.get('DYNAMODB_TABLE_NAME', 'poc-chargeback-chargebacks-dev')
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for processing MSK Kafka events.
    
    Args:
        event: MSK event containing Kafka messages
        context: Lambda context object
        
    Returns:
        Dict with batchItemFailures for partial batch failure handling
    """
    logger.info(f"Received event from {event.get('eventSource', 'unknown')}")
    logger.debug(f"Full event: {json.dumps(event)}")
    
    batch_item_failures = []
    messages_processed = 0
    messages_failed = 0
    chargebacks_updated = 0
    
    try:
        # Parse Kafka messages from MSK event
        kafka_messages = parse_kafka_messages(event)
        logger.info(f"Parsed {len(kafka_messages)} Kafka messages")
        
        # Process each message
        for message in kafka_messages:
            try:
                # Decode and parse consolidation event
                consolidation_event = parse_consolidation_event(message)
                
                if not consolidation_event:
                    logger.warning(f"Skipping invalid message at offset {message.get('offset')}")
                    continue
                
                logger.info(f"Processing consolidation event: {consolidation_event.get('partition_date')}")
                
                # Update DynamoDB records for this partition
                updated_count = update_dynamodb_records(consolidation_event)
                chargebacks_updated += updated_count
                messages_processed += 1
                
                logger.info(f"Updated {updated_count} chargeback records for partition {consolidation_event.get('partition_date')}")
                
            except Exception as e:
                logger.error(f"Failed to process message at offset {message.get('offset')}: {str(e)}", exc_info=True)
                messages_failed += 1
                
                # Add to batch item failures for retry
                batch_item_failures.append({
                    'itemIdentifier': f"{message.get('topic')}-{message.get('partition')}-{message.get('offset')}"
                })
        
        # Log summary metrics
        logger.info(f"METRICS: messages_processed={messages_processed}, "
                   f"messages_failed={messages_failed}, "
                   f"chargebacks_updated={chargebacks_updated}")
        
        # Publish custom CloudWatch metrics
        publish_metrics(messages_processed, messages_failed, chargebacks_updated)
        
    except Exception as e:
        logger.error(f"Fatal error processing batch: {str(e)}", exc_info=True)
        raise
    
    # Return batch item failures for Lambda to retry
    return {
        'batchItemFailures': batch_item_failures
    }


def parse_kafka_messages(event: Dict[str, Any]) -> List[Dict[str, Any]]:
    """
    Extract Kafka messages from MSK event structure.
    
    Args:
        event: MSK Lambda event
        
    Returns:
        List of Kafka message dictionaries
    """
    messages = []
    records = event.get('records', {})
    
    # MSK event structure: records is a dict with topic-partition as keys
    for topic_partition, partition_messages in records.items():
        for message in partition_messages:
            messages.append(message)
    
    return messages


def parse_consolidation_event(message: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Parse and validate a consolidation event from Kafka message.
    
    Args:
        message: Kafka message dictionary
        
    Returns:
        Parsed consolidation event or None if invalid
    """
    try:
        # Decode base64 value
        value_bytes = base64.b64decode(message.get('value', ''))
        value_str = value_bytes.decode('utf-8')
        
        # Parse JSON
        event_data = json.loads(value_str)
        
        # Validate required fields
        required_fields = [
            'event_type',
            'partition_date',
            'execution_sequence',
            'total_executions',
            'records_processed',
            'output_files',
            'output_format',
            'output_path',
            'completed_at',
            'job_name'
        ]
        
        for field in required_fields:
            if field not in event_data:
                logger.warning(f"Missing required field: {field}")
                return None
        
        # Validate event type
        if event_data['event_type'] != 'consolidation_completed':
            logger.warning(f"Unknown event type: {event_data['event_type']}")
            return None
        
        return event_data
        
    except (ValueError, json.JSONDecodeError) as e:
        logger.error(f"Failed to parse message value: {str(e)}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error parsing message: {str(e)}", exc_info=True)
        return None


def update_dynamodb_records(consolidation_event: Dict[str, Any]) -> int:
    """
    Update DynamoDB chargeback records with consolidation metadata.
    
    This function queries DynamoDB to find all chargebacks for the given partition date
    and updates them with consolidation information.
    
    Args:
        consolidation_event: Parsed consolidation event
        
    Returns:
        Number of records updated
    """
    partition_date = consolidation_event['partition_date']
    updated_count = 0
    
    try:
        # Query chargebacks by partition date
        # Note: This assumes chargebacks have a 'created_at' field in YYYY-MM-DD format
        # Adjust the query based on your actual DynamoDB schema
        
        # Option 1: Scan with filter (for POC - not recommended for production)
        response = table.scan(
            FilterExpression='begins_with(created_at, :date)',
            ExpressionAttributeValues={
                ':date': partition_date
            }
        )
        
        chargebacks = response.get('Items', [])
        logger.info(f"Found {len(chargebacks)} chargebacks for partition date {partition_date}")
        
        # Update each chargeback
        for chargeback in chargebacks:
            chargeback_id = chargeback.get('chargeback_id')
            
            if not chargeback_id:
                logger.warning(f"Chargeback missing chargeback_id: {chargeback}")
                continue
            
            try:
                update_chargeback(chargeback_id, consolidation_event)
                updated_count += 1
                
            except ClientError as e:
                logger.error(f"Failed to update chargeback {chargeback_id}: {str(e)}")
                # Continue processing other records
                continue
        
        return updated_count
        
    except ClientError as e:
        logger.error(f"DynamoDB query failed: {str(e)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"Unexpected error updating records: {str(e)}", exc_info=True)
        raise


def update_chargeback(chargeback_id: str, consolidation_event: Dict[str, Any]) -> None:
    """
    Update a single chargeback record with consolidation metadata.
    
    Args:
        chargeback_id: DynamoDB partition key
        consolidation_event: Consolidation event data
    """
    update_expression = (
        'SET consolidation_status = :status, '
        'consolidation_s3_path = :path, '
        'consolidation_date = :date, '
        'consolidation_execution = :execution, '
        'consolidation_job_name = :job_name, '
        'output_format = :format, '
        'records_in_consolidation = :records, '
        'updated_at = :updated'
    )
    
    expression_values = {
        ':status': 'completed',
        ':path': consolidation_event['output_path'],
        ':date': consolidation_event['completed_at'],
        ':execution': consolidation_event['execution_sequence'],
        ':job_name': consolidation_event['job_name'],
        ':format': consolidation_event['output_format'],
        ':records': consolidation_event['records_processed'],
        ':updated': datetime.utcnow().isoformat() + 'Z'
    }
    
    table.update_item(
        Key={'chargeback_id': chargeback_id},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_values,
        ReturnValues='NONE'
    )
    
    logger.debug(f"Updated chargeback {chargeback_id} with consolidation metadata")


def publish_metrics(processed: int, failed: int, updated: int) -> None:
    """
    Publish custom CloudWatch metrics.
    
    Args:
        processed: Number of messages successfully processed
        failed: Number of messages that failed
        updated: Number of chargebacks updated
    """
    try:
        namespace = 'POC-Chargeback/ConsolidationUpdater'
        
        metrics = [
            {
                'MetricName': 'MessagesProcessed',
                'Value': processed,
                'Unit': 'Count'
            },
            {
                'MetricName': 'MessagesFailed',
                'Value': failed,
                'Unit': 'Count'
            },
            {
                'MetricName': 'ChargebacksUpdated',
                'Value': updated,
                'Unit': 'Count'
            }
        ]
        
        for metric in metrics:
            cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[{
                    'MetricName': metric['MetricName'],
                    'Value': metric['Value'],
                    'Unit': metric['Unit'],
                    'Timestamp': datetime.utcnow()
                }]
            )
        
        logger.debug(f"Published {len(metrics)} CloudWatch metrics")
        
    except Exception as e:
        # Don't fail the function if metrics publishing fails
        logger.warning(f"Failed to publish CloudWatch metrics: {str(e)}")
