import boto3
import json
import os
from datetime import datetime, timedelta

cloudwatch = boto3.client('cloudwatch')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    alb_arn = os.environ['ALB_ARN']
    tg_arn = os.environ['TARGET_GROUP_ARN']
    table_name = os.environ.get('DYNAMODB_TABLE', 'ip-tracker-investigations')
    
    table = dynamodb.Table(table_name)
    
    # Check for recent investigation (last 10 minutes)
    try:
        response = table.get_item(Key={'resource_arn': alb_arn})
        
        if 'Item' in response:
            item = response['Item']
            last_timestamp = datetime.fromisoformat(item['timestamp'])
            
            # If investigation is less than 10 minutes old and still in progress
            if (datetime.now() - last_timestamp) < timedelta(minutes=10):
                if item.get('status') == 'IN_PROGRESS':
                    print(f"Investigation already running: {item['investigation_id']}")
                    return {
                        'statusCode': 200,
                        'investigation_id': item['investigation_id'],
                        'message': 'Investigation already in progress',
                        'skipped': True
                    }
    except Exception as e:
        print(f"DynamoDB check failed: {e}")
    
    # Start new investigation
    print(f"Starting investigation for ALB: {alb_arn}")
    
    try:
        response = cloudwatch.start_investigation(
            ResourceArns=[alb_arn, tg_arn]
        )
        
        investigation_id = response['InvestigationId']
        print(f"Investigation started: {investigation_id}")
        
        # Store investigation in DynamoDB
        table.put_item(Item={
            'resource_arn': alb_arn,
            'investigation_id': investigation_id,
            'timestamp': datetime.now().isoformat(),
            'status': 'IN_PROGRESS',
            'ttl': int((datetime.now() + timedelta(hours=1)).timestamp())
        })
        
        return {
            'statusCode': 200,
            'investigation_id': investigation_id,
            'message': 'Investigation started successfully',
            'skipped': False
        }
        
    except Exception as e:
        print(f"Failed to start investigation: {e}")
        return {
            'statusCode': 500,
            'error': str(e)
        }
