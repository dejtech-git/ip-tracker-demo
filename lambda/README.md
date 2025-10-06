# Lambda Functions for CloudWatch Investigation Automation

## Overview

These Lambda functions enable automated incident response by connecting CloudWatch Investigations with GitHub and Amazon Q Developer.

## Functions

### 1. start_investigation.py
**Trigger:** SNS (from CloudWatch Alarm)  
**Purpose:** Starts a CloudWatch Investigation when 503 errors are detected

**Environment Variables:**
- `ALB_ARN` - Application Load Balancer ARN
- `TARGET_GROUP_ARN` - Target Group ARN

### 2. create_github_issue.py
**Trigger:** EventBridge (Investigation completion)  
**Purpose:** Creates GitHub issue with investigation findings for Amazon Q Developer

**Environment Variables:**
- `GITHUB_TOKEN_SECRET` - ARN of Secrets Manager secret containing GitHub token
- `GITHUB_REPO_OWNER` - GitHub repository owner (e.g., "dejtech-git")
- `GITHUB_REPO_NAME` - GitHub repository name (e.g., "ip-tracker-demo")

**Dependencies:**
- `requests` library (packaged with function)

## Packaging

Run the packaging script to create deployment packages:

```bash
./package.sh
```

This creates:
- `lambda_start_investigation.zip`
- `lambda_github_issue.zip`

## Deployment

These functions are deployed automatically via Terraform:

```bash
terraform apply
```

## Testing

**Test start_investigation:**
```bash
aws lambda invoke \
  --function-name ip-tracker-start-investigation \
  --payload '{"Records":[{"Sns":{"Message":"{\"AlarmName\":\"test-alarm\"}"}}]}' \
  response.json
```

**Test create_github_issue:**
```bash
aws lambda invoke \
  --function-name ip-tracker-investigation-to-github \
  --payload '{"detail":{"investigationId":"test-123","status":"COMPLETED"}}' \
  response.json
```

## Logs

View logs in CloudWatch:
```bash
aws logs tail /aws/lambda/ip-tracker-start-investigation --follow
aws logs tail /aws/lambda/ip-tracker-investigation-to-github --follow
```
