import json
import boto3
import ftplib
import logging
import os
from typing import Dict, Any, List
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
secrets_client = boto3.client('secretsmanager')
sns_client = boto3.client('sns')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda function to upload CSV files to card company FTP servers
    """
    try:
        logger.info(f"Starting FTP upload for event: {json.dumps(event)}")
        
        # Extract file information from event
        files_to_upload = event.get('generated_files', [])
        
        if not files_to_upload:
            raise ValueError("No files specified for upload")
        
        # Get FTP credentials from Secrets Manager
        ftp_config = get_ftp_credentials()
        
        # Upload files to FTP
        upload_results = []
        
        for file_info in files_to_upload:
            bucket = file_info['bucket']
            key = file_info['key']
            
            try:
                # Download file from S3
                response = s3_client.get_object(Bucket=bucket, Key=key)
                file_content = response['Body'].read()
                
                # Upload to FTP
                remote_filename = os.path.basename(key)
                upload_success = upload_to_ftp(
                    file_content, 
                    remote_filename, 
                    ftp_config
                )
                
                upload_results.append({
                    'file': f"s3://{bucket}/{key}",
                    'remote_filename': remote_filename,
                    'success': upload_success,
                    'size': len(file_content)
                })
                
                logger.info(f"Upload {'successful' if upload_success else 'failed'}: {remote_filename}")
                
            except Exception as e:
                logger.error(f"Error uploading file {key}: {str(e)}")
                upload_results.append({
                    'file': f"s3://{bucket}/{key}",
                    'success': False,
                    'error': str(e)
                })
        
        # Send notification
        successful_uploads = sum(1 for result in upload_results if result.get('success'))
        total_files = len(upload_results)
        
        notification_message = {
            'total_files': total_files,
            'successful_uploads': successful_uploads,
            'failed_uploads': total_files - successful_uploads,
            'upload_results': upload_results,
            'timestamp': event.get('timestamp')
        }
        
        # Send SNS notification (would use actual topic ARN from environment)
        logger.info(f"Upload completed: {successful_uploads}/{total_files} files successful")
        
        return {
            'statusCode': 200,
            'upload_results': upload_results,
            'summary': {
                'total_files': total_files,
                'successful': successful_uploads,
                'failed': total_files - successful_uploads
            }
        }
        
    except Exception as e:
        logger.error(f"Error in FTP upload process: {str(e)}")
        return {
            'statusCode': 500,
            'error': str(e)
        }

def get_ftp_credentials() -> Dict[str, str]:
    """
    Retrieve FTP credentials from AWS Secrets Manager
    """
    try:
        secret_name = os.environ.get('FTP_SECRET_NAME', 'chargeback/ftp-credentials')
        
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_data = json.loads(response['SecretString'])
        
        required_fields = ['host', 'username', 'password', 'port']
        for field in required_fields:
            if field not in secret_data:
                raise ValueError(f"Missing required FTP credential: {field}")
        
        return secret_data
        
    except ClientError as e:
        logger.error(f"Error retrieving FTP credentials: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Error parsing FTP credentials: {str(e)}")
        raise

def upload_to_ftp(file_content: bytes, filename: str, ftp_config: Dict[str, str]) -> bool:
    """
    Upload file content to FTP server
    """
    ftp = None
    try:
        # Connect to FTP server
        ftp = ftplib.FTP()
        ftp.connect(ftp_config['host'], int(ftp_config.get('port', 21)))
        ftp.login(ftp_config['username'], ftp_config['password'])
        
        # Set passive mode
        ftp.set_pasv(True)
        
        # Change to target directory if specified
        if 'directory' in ftp_config:
            ftp.cwd(ftp_config['directory'])
        
        # Upload file
        from io import BytesIO
        file_obj = BytesIO(file_content)
        ftp.storbinary(f'STOR {filename}', file_obj)
        
        logger.info(f"Successfully uploaded {filename} to FTP server")
        return True
        
    except Exception as e:
        logger.error(f"FTP upload failed for {filename}: {str(e)}")
        return False
        
    finally:
        if ftp:
            try:
                ftp.quit()
            except:
                pass