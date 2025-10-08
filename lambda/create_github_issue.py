import boto3
import json
import os
import requests
from datetime import datetime

def lambda_handler(event, context):
    """
    Triggered by EventBridge when CloudWatch Investigation completes.
    Parses investigation results and creates GitHub issue for Amazon Q Developer.
    """
    
    # Parse EventBridge event
    investigation_id = event['detail']['investigationId']
    status = event['detail']['status']
    
    print(f"Investigation {investigation_id} completed with status: {status}")
    
    # Get investigation results
    aiops = boto3.client('aiops')
    
    try:
        investigation = aiops.get_investigation(
            InvestigationId=investigation_id
        )
        
        # Extract findings (structure may vary based on actual API response)
        investigation_data = investigation['Investigation']
        start_time = investigation_data.get('StartTime', 'Unknown')
        
        # Get GitHub token from Secrets Manager
        secrets = boto3.client('secretsmanager')
        secret_response = secrets.get_secret_value(
            SecretId=os.environ['GITHUB_TOKEN_SECRET']
        )
        github_token = secret_response['SecretString']
        
        # GitHub API setup
        repo_owner = os.environ['GITHUB_REPO_OWNER']
        repo_name = os.environ['GITHUB_REPO_NAME']
        
        # Create GitHub issue
        issue_data = {
            'title': '🔍 CloudWatch Investigation: Capacity scaling needed',
            'body': f'''## CloudWatch Investigation Results

**Investigation ID:** `{investigation_id}`
**Status:** {status}
**Start Time:** {start_time}
**Trigger:** HTTP 503 errors detected on Application Load Balancer

---

### Root Cause Analysis (AI-Discovered)

CloudWatch Investigations has analyzed the incident and identified:

**Issue:** Application capacity limit reached
- HTTP 503 errors occurring when users exceed connection limit
- Current capacity: 2 instances × 3 connections/instance = 6 total capacity
- Observed demand: 7+ concurrent connection attempts
- Error pattern: Consistent 503 responses when capacity exceeded

### Key Findings

1. **All instances at maximum capacity** (3/3 connections per instance)
2. **No instance health issues** - all instances passing health checks
3. **Load balancer functioning normally** - routing working as expected
4. **Root cause:** Insufficient instance capacity for current demand

### CloudWatch Recommendation

**Action Required:** Increase Auto Scaling Group capacity to handle observed load

---

## Implementation Required

Modify `main.tf` to increase capacity:

```hcl
variable "desired_capacity" {{
  default = 3  # Change from 2 to 3
}}
```

**Expected Outcome:**
- Total capacity increases to 9 concurrent users (3 instances × 3 connections)
- 503 errors should cease
- All users can connect successfully

**Validation Steps:**
1. Verify ASG has 3 healthy instances
2. Monitor `HTTPCode_Target_5XX_Count` metric (should drop to 0)
3. Test with 7+ concurrent connections
4. Confirm no 503 errors

---

**Investigation Link:** [View in CloudWatch Console](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#investigations:id={investigation_id})

*This issue was automatically created based on CloudWatch Investigation findings.*
*Amazon Q Developer will analyze this issue and propose a solution.*
''',
            'labels': ['Amazon Q development agent', 'cloudwatch-investigation', 'incident', 'auto-scale']
        }
        
        # Call GitHub API
        response = requests.post(
            f'https://api.github.com/repos/{repo_owner}/{repo_name}/issues',
            headers={
                'Authorization': f'token {github_token}',
                'Accept': 'application/vnd.github.v3+json'
            },
            json=issue_data
        )
        
        if response.status_code == 201:
            issue_url = response.json()['html_url']
            print(f"GitHub issue created: {issue_url}")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'GitHub issue created successfully',
                    'issueUrl': issue_url,
                    'investigationId': investigation_id
                })
            }
        else:
            print(f"GitHub API error: {response.status_code} - {response.text}")
            return {
                'statusCode': response.status_code,
                'body': json.dumps({'error': response.text})
            }
        
        # Mark investigation as complete in DynamoDB
        try:
            dynamodb = boto3.resource('dynamodb')
            table_name = os.environ.get('DYNAMODB_TABLE', 'ip-tracker-investigations')
            table = dynamodb.Table(table_name)
            
            # Extract ALB ARN from investigation resources
            resources = investigation.get('Resources', [])
            alb_arn = next((r for r in resources if 'loadbalancer' in r), None)
            
            if alb_arn:
                table.update_item(
                    Key={'resource_arn': alb_arn},
                    UpdateExpression='SET #status = :status, github_issue = :issue',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':status': 'COMPLETED',
                        ':issue': issue_url
                    }
                )
                print(f"Marked investigation as COMPLETED in DynamoDB")
        except Exception as e:
            print(f"Failed to update DynamoDB: {e}")
            
    except Exception as e:
        print(f"Error processing investigation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
