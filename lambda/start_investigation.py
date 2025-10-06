import boto3
import json
import os
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """
    Triggered by SNS when CloudWatch Alarm detects 503 errors.
    Starts a CloudWatch Investigation to analyze the root cause.
    """
    
    # Parse SNS message
    sns_message = json.loads(event['Records'][0]['Sns']['Message'])
    alarm_name = sns_message.get('AlarmName', 'Unknown')
    
    print(f"Alarm triggered: {alarm_name}")
    
    # Initialize CloudWatch client
    cloudwatch = boto3.client('cloudwatch')
    
    # Get environment variables
    alb_arn = os.environ['ALB_ARN']
    target_group_arn = os.environ['TARGET_GROUP_ARN']
    
    # Start CloudWatch Investigation
    try:
        response = cloudwatch.start_investigation(
            InvestigationName=f'503-errors-{datetime.utcnow().strftime("%Y%m%d-%H%M%S")}',
            StartTime=datetime.utcnow() - timedelta(minutes=15),
            EndTime=datetime.utcnow(),
            ResourceArns=[alb_arn, target_group_arn],
            Tags=[
                {'Key': 'Type', 'Value': 'AutomatedIncidentResponse'},
                {'Key': 'Trigger', 'Value': 'HTTP503Errors'},
                {'Key': 'AlarmName', 'Value': alarm_name}
            ]
        )
        
        investigation_id = response['InvestigationId']
        print(f"Started investigation: {investigation_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Investigation started',
                'investigationId': investigation_id
            })
        }
        
    except Exception as e:
        print(f"Error starting investigation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
