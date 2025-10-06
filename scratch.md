# Workshop Highlights & Notes

## Session Log

**Date:** October 7, 2025  
**Workshop:** CloudWatch Investigations Demo with IP Tracker Application

---

## Key Accomplishments

### Infrastructure Setup
- ✅ Deployed AWS infrastructure with Terraform (VPC, ALB, ASG, ElastiCache Redis, EC2)
- ✅ Configured 3 concurrent connections per instance limit
- ✅ Implemented IMDSv1/v2 support for EC2 instance ID retrieval
- ✅ Added CloudWatch Logs agent for system log collection
- ✅ Configured IAM roles with CloudWatch Logs and metrics permissions

### Application Features
- ✅ Real-time WebSocket connection tracking
- ✅ Duration counter with separate start_time and timestamp fields
- ✅ QR code generation for mobile access
- ✅ Browser/OS detection from User-Agent
- ✅ Redis-based session management across instances
- ✅ Sticky sessions with ALB

### CloudWatch Investigations Setup
- ✅ Created demo guide with two scenarios
- ✅ Configured CloudWatch Logs collection
- ✅ Prepared for CloudTrail integration
- ✅ Set up metrics collection for custom namespace

---

## Demo Scenarios

### Scenario 1: Capacity Issue (503 Errors)
**Objective:** CloudWatch Investigations discovers capacity constraints from 3-user limit

**Key Points:**
- Open 6+ browser tabs to exceed capacity
- Generates HTTP 503 errors
- CloudWatch correlates error spike with capacity limit
- AI suggests scaling out

### Scenario 2: Security Group Misconfiguration
**Objective:** CloudWatch Investigations correlates CloudTrail events with service disruption

**Key Points:**
- Remove ALB security group ingress rule
- Service becomes unreachable
- CloudWatch correlates CloudTrail `RevokeSecurityGroupIngress` event
- AI identifies root cause and suggests fix

---

## Technical Highlights

### Issues Resolved
1. **Empty Instance ID** - Fixed by adding MetadataOptions to launch template
2. **Duration Counter Reset** - Separated start_time from timestamp field
3. **Connection Limit** - Changed from 5 to 3 users per instance
4. **IMDSv2 Support** - Added token-based metadata retrieval with fallback

### Launch Template Versions
- Version 5: Original working version
- Version 6: Added MetadataOptions
- Version 7: Added IMDSv1/v2 support, separate start_time, 3-connection limit
- Version 8: Terraform reconciliation
- Version 9: All fixes deployed
- Version 10: Added CloudWatch Logs agent (current)

### Key Configuration
- **Connection Limit:** 3 per instance
- **Session Timeout:** 300 seconds (5 minutes)
- **Heartbeat Interval:** 30 seconds
- **Auto Scaling:** min=1, max=10, desired=2
- **Load Balancing:** least_outstanding_requests with sticky sessions

---

## Workshop Preparation Checklist

### Before Workshop
- [ ] Verify CloudWatch Investigations is configured
- [ ] Confirm CloudTrail is logging
- [ ] Test application is accessible
- [ ] Verify CloudWatch Logs are being collected
- [ ] Prepare multiple browser tabs/devices for load testing

### During Workshop
- [ ] Demonstrate normal application behavior
- [ ] Execute Scenario 1 (capacity issue)
- [ ] Show CloudWatch Investigations analysis
- [ ] Execute Scenario 2 (security group change)
- [ ] Show CloudTrail correlation
- [ ] Restore service and verify

### After Workshop
- [ ] Clean up test resources
- [ ] Review investigation results
- [ ] Document lessons learned

---

## Important Commands

### Deploy/Update Infrastructure
```bash
terraform apply
```

### Force Instance Refresh
```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name ip-tracker-asg \
  --preferences '{"MinHealthyPercentage": 0, "InstanceWarmup": 60}' \
  --region us-east-1
```

### Check Instance Health
```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1
```

### Break Service (Scenario 2)
```bash
ALB_SG=$(aws elbv2 describe-load-balancers \
  --names ip-tracker-alb \
  --query 'LoadBalancers[0].SecurityGroups[0]' \
  --output text \
  --region us-east-1)

aws ec2 revoke-security-group-ingress \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region us-east-1
```

### Restore Service
```bash
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --region us-east-1
```

---

## Notes & Observations

### What CloudWatch Investigations Can Discover
- ✅ Correlate CloudTrail events with service disruptions
- ✅ Identify patterns in error rates and response times
- ✅ Detect capacity constraints from metric patterns
- ✅ Analyze log patterns for error messages
- ✅ Suggest infrastructure changes based on observed behavior
- ✅ Provide root cause hypotheses with supporting evidence

### Key Insight
CloudWatch Investigations doesn't need application documentation - it analyzes actual telemetry data (metrics, logs, traces, events) to understand behavior and identify issues.

---

## Resources

- Application Spec: [IP-Tracker-app-spec.md](./IP-Tracker-app-spec.md)
- Demo Guide: [CLOUDWATCH_INVESTIGATIONS_DEMO.md](./CLOUDWATCH_INVESTIGATIONS_DEMO.md)
- Website URL: http://ip-tracker-alb-306488846.us-east-1.elb.amazonaws.com/app-x7k9m2n8/

---

## Additional Notes

_Add your workshop observations and highlights here..._
