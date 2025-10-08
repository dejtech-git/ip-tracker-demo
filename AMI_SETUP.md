# Custom AMI Setup Guide

## For New Accounts (First Deployment)

1. **Initial deployment with base AMI:**
```bash
terraform init
terraform apply
```

This will use the full `user_data_working.sh` script (takes 3-5 minutes per instance).

2. **Create custom AMI after first deployment:**
```bash
# Get a healthy instance ID
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

# Wait for AMI to be available
aws ec2 wait image-available --image-ids $AMI_ID
echo "✅ AMI is ready"
```

3. **Update terraform.tfvars:**
```hcl
use_custom_ami = true
custom_ami_id  = "ami-xxxxx"  # Use the AMI ID from step 2
```

4. **Apply changes:**
```bash
terraform apply
```

5. **Refresh instances to use new AMI:**
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name ip-tracker-asg \
  --preferences '{"MinHealthyPercentage":50,"InstanceWarmup":60}'
```

## Benefits

- **Startup time:** 3-5 minutes → 60-90 seconds
- **User data:** 457 lines → 25 lines (only dynamic config)
- **Reliability:** Pre-tested application environment

## For Existing Deployments

If you already have a custom AMI, just set the variables in `terraform.tfvars`:

```hcl
use_custom_ami = true
custom_ami_id  = "ami-01ddfbb33f294a6e8"
```

## Updating Application Code

With custom AMI, to update application code:

1. **Option A:** Create new AMI with updated code
2. **Option B:** Use Parameter Store/S3 to pull latest code in user_data
3. **Option C:** Use container approach (Docker)

Current setup uses Option A (baked into AMI).
