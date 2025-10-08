# Deployment Guide for New AWS Accounts

## Prerequisites

- AWS CLI configured with credentials
- Terraform installed (v1.0+)
- GitHub personal access token (for automated issue creation)

## Step 1: Initial Deployment

```bash
# Clone repository
cd Demo1

# Initialize Terraform
terraform init

# Deploy infrastructure (uses base Amazon Linux AMI)
terraform apply
```

**Expected time:** 5-10 minutes
- Infrastructure creation: 3-5 minutes
- First instance startup: 3-5 minutes (full user_data execution)

## Step 2: Configure CloudWatch Investigations (Optional)

1. Go to CloudWatch Console → AI Operations → Investigations
2. Click "Configure for this account"
3. Accept defaults (90-day retention, auto-create IAM role)
4. Complete setup

## Step 3: Configure Alarm to Auto-Start Investigations

1. Go to CloudWatch Console → Alarms
2. Select alarm: `ip-tracker-503-investigation-trigger`
3. Click Actions → Edit
4. Under Alarm actions, add:
   - Action type: **Start CloudWatch Investigation**
5. Save

## Step 4: Add GitHub Token

```bash
# Get secret ARN from Terraform output
SECRET_ARN=$(terraform output -raw github_token_secret_arn)

# Add your GitHub token
aws secretsmanager put-secret-value \
  --secret-id $SECRET_ARN \
  --secret-string "ghp_your_token_here"
```

## Step 5: Create Custom AMI (Optional but Recommended)

**Benefits:** Reduces instance startup from 3-5 minutes to 60-90 seconds

```bash
# Get healthy instance ID
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ip-tracker-asg \
  --query 'AutoScalingGroups[0].Instances[?HealthStatus==`Healthy`].InstanceId' \
  --output text | head -1)

# Create AMI
AMI_ID=$(aws ec2 create-image \
  --instance-id $INSTANCE_ID \
  --name "ip-tracker-app-$(date +%Y%m%d-%H%M)" \
  --description "IP Tracker with pre-installed dependencies" \
  --query 'ImageId' \
  --output text)

echo "AMI created: $AMI_ID"

# Wait for AMI
aws ec2 wait image-available --image-ids $AMI_ID
```

## Step 6: Update to Use Custom AMI

Edit `terraform.tfvars`:

```hcl
use_custom_ami = true
custom_ami_id  = "ami-xxxxx"  # Your AMI ID from Step 5
```

Apply changes:

```bash
terraform apply

# Refresh instances to use new AMI
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name ip-tracker-asg \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":60}'
```

## Verification

1. **Check application:**
```bash
terraform output website_url
# Visit the URL in browser
```

2. **Test 503 error detection:**
```bash
# Open 4+ browser tabs simultaneously to exceed capacity
# Alarm should trigger after 3+ errors within 60 seconds
```

3. **Verify automation:**
- CloudWatch Investigation starts automatically
- After manual closure, GitHub issue is created
- Amazon Q Developer picks up issue (if configured)

## Outputs

```bash
terraform output
```

Key outputs:
- `website_url` - Application URL
- `load_balancer_dns` - ALB DNS name
- `redis_endpoint` - Redis endpoint
- `github_token_secret_arn` - Secret ARN for GitHub token
- `investigation_alarm_name` - CloudWatch alarm name

## Troubleshooting

**Issue: Instances not starting**
```bash
# Check ASG
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ip-tracker-asg

# Check instance logs
aws ssm start-session --target <instance-id>
sudo journalctl -u ip-tracker -f
```

**Issue: Application returns 503**
- Check if SpringClean Lambda terminated instances
- Verify ASG desired capacity > 0
- Check target group health

**Issue: Alarm not triggering**
- Verify 3+ errors within 60 seconds
- Check CloudWatch metrics for HTTPCode_Target_5XX_Count

## Clean Up

```bash
terraform destroy
```

**Note:** Custom AMIs are not deleted by Terraform. Delete manually:
```bash
aws ec2 deregister-image --image-id <ami-id>
```
