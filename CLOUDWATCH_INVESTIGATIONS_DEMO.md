# CloudWatch Investigations Demo Guide

## Application Context for CloudWatch Investigations

**Application:** Real-time IP Tracker for ES Sharing
- **Connection Limit:** 3 concurrent users per EC2 instance
- **Behavior:** Returns HTTP 503 error with message "Maximum 3 users reached" when limit exceeded
- **Auto Scaling:** Configured with min=1, max=10, desired=2
- **Load Balancer:** ALB with sticky sessions

## Prerequisites

1. **Deploy Updated Infrastructure:**
   ```bash
   terraform apply
   ```

2. **Setup CloudWatch Investigations:**
   - Go to CloudWatch Console → AI Operations → Investigations
   - Click "Configure for this account"
   - Follow the setup wizard (retention: 90 days, auto-create IAM role)
   - Enable CloudTrail integration for change detection
   - Complete setup

3. **Verify CloudTrail is Active:**
   ```bash
   aws cloudtrail describe-trails --region us-east-1
   aws cloudtrail get-trail-status --name <trail-name> --region us-east-1
   ```

## Demo Scenario 1: Capacity Issue (503 Errors)

**Objective:** CloudWatch Investigations discovers that 503 errors are caused by reaching the 3-user limit per instance.

**Steps:**

1. **Generate Load - Reach 3 Users Per Instance:**
   ```bash
   # Open 6 browser tabs/windows to the application URL
   # With 2 instances, this fills all capacity (3 users × 2 instances = 6 total)
   ```

2. **Trigger 503 Errors:**
   ```bash
   # Open a 7th browser tab - this should show "Maximum 3 users reached"
   # The ALB will return HTTP 503
   ```

3. **Monitor Metrics:**
   ```bash
   # Check ALB metrics
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ApplicationELB \
     --metric-name HTTPCode_Target_5XX_Count \
     --dimensions Name=LoadBalancer,Value=<your-alb-arn-suffix> \
     --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 60 \
     --statistics Sum \
     --region us-east-1
   ```

4. **Start CloudWatch Investigation:**
   - Go to CloudWatch Console → AI Operations → Investigations
   - Click "Start investigation"
   - Select time range covering the last 10-15 minutes
   - Add resources: Select your ALB and target group
   - Click "Start investigation"

5. **Expected Investigation Results:**
   - CloudWatch should identify:
     - Spike in HTTP 503 errors
     - Pattern: Errors occur when connection attempts exceed capacity
     - Correlation: All instances showing healthy but at capacity
     - Suggestion: Scale out to add more instances

## Demo Scenario 2: Security Group Misconfiguration

**Objective:** CloudWatch Investigations correlates CloudTrail events with service disruption.

**Steps:**

1. **Baseline - Verify Service is Working:**
   ```bash
   curl -I http://<your-alb-dns>/app-x7k9m2n8/
   # Should return HTTP 200
   ```

2. **Break the Service - Modify Security Group:**
   ```bash
   # Get ALB security group ID
   ALB_SG=$(aws elbv2 describe-load-balancers \
     --names ip-tracker-alb \
     --query 'LoadBalancers[0].SecurityGroups[0]' \
     --output text \
     --region us-east-1)
   
   # Remove all ingress rules (deny all incoming traffic)
   aws ec2 revoke-security-group-ingress \
     --group-id $ALB_SG \
     --protocol tcp \
     --port 80 \
     --cidr 0.0.0.0/0 \
     --region us-east-1
   ```

3. **Verify Service is Broken:**
   ```bash
   curl -I http://<your-alb-dns>/app-x7k9m2n8/ --max-time 10
   # Should timeout or fail to connect
   ```

4. **Start CloudWatch Investigation:**
   - Go to CloudWatch Console → AI Operations → Investigations
   - Click "Start investigation"
   - Select time range covering the last 10-15 minutes
   - Add resources: Select your ALB
   - Click "Start investigation"

5. **Expected Investigation Results:**
   - CloudWatch should identify:
     - Sudden drop in request count
     - Connection timeouts
     - CloudTrail event: `RevokeSecurityGroupIngress` API call
     - Correlation: Service disruption started immediately after security group change
     - Root cause: Security group rule removal blocking traffic
     - Suggestion: Review recent security group changes

6. **Restore Service:**
   ```bash
   # Add the ingress rule back
   aws ec2 authorize-security-group-ingress \
     --group-id $ALB_SG \
     --protocol tcp \
     --port 80 \
     --cidr 0.0.0.0/0 \
     --region us-east-1
   
   # Verify service is restored
   curl -I http://<your-alb-dns>/app-x7k9m2n8/
   ```

## Tips for Better Investigation Results

1. **Wait 5-10 minutes** after triggering issues before starting investigation (allows metrics to populate)
2. **Be specific with time ranges** - narrow windows help CloudWatch focus on relevant data
3. **Add context** - Use the investigation feed to add notes about what you were testing
4. **Review suggestions** - CloudWatch may provide multiple hypotheses, review all of them
5. **Check CloudTrail integration** - Ensure CloudTrail is enabled for change detection

## Cleanup

After demo, restore normal operations:
```bash
# Ensure security group rules are correct
# Close extra browser tabs to reduce load
# Optionally scale down to desired capacity of 1 if needed
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ip-tracker-asg \
  --desired-capacity 1 \
  --region us-east-1
```

## What CloudWatch Investigations Can Discover

Without explicit alarms, CloudWatch Investigations can:
- ✅ Correlate CloudTrail events with service disruptions
- ✅ Identify patterns in error rates and response times
- ✅ Detect capacity constraints from metric patterns
- ✅ Analyze log patterns for error messages
- ✅ Suggest infrastructure changes based on observed behavior
- ✅ Provide root cause hypotheses with supporting evidence

The AI doesn't need to "read" your README - it analyzes actual telemetry data (metrics, logs, traces, events) to understand application behavior and identify issues.
