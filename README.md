# Real-time IP Tracker for ES Sharing - Auto-Scaling Demo

This repository contains a scalable web application demonstrating AWS auto-scaling capabilities with improved capacity management.

## 📦 Components

### 1. IP Tracker Application
A real-time web application with enhanced auto-scaling capabilities that can handle high user loads.

**See:** [IP-Tracker-app-spec.md](./IP-Tracker-app-spec.md) for complete application documentation.

### 2. CloudWatch Investigations Demo
Hands-on demonstration of AWS CloudWatch Investigations for AI-assisted troubleshooting.

**See:** [CLOUDWATCH_INVESTIGATIONS_DEMO.md](./CLOUDWATCH_INVESTIGATIONS_DEMO.md) for demo scenarios and instructions.

### 3. Automated Incident Response
AI-driven workflow that automatically creates GitHub issues from CloudWatch Investigations, triggering Amazon Q Developer to generate remediation pull requests.

**Flow:** 503 Errors → CloudWatch Investigation → GitHub Issue → Q Developer PR

**See:** [scratch.md](./scratch.md#cloudwatch-investigation--github-q-developer-integration) for setup instructions.

## 🚀 Quick Start

### Deploy Infrastructure
```bash
# Make deployment script executable
chmod +x deploy.sh

# Deploy with improved auto-scaling
./deploy.sh
```

Or manually:
```bash
terraform init
terraform apply
```

### Access Application
Use the `website_url` output from Terraform:
```
http://ip-tracker-alb-306488846.us-east-1.elb.amazonaws.com/app-x7k9m2n8/
```

## 🔧 Key Improvements

### Enhanced Scaling Capabilities
- **25 concurrent users per instance** (increased from 3, configurable via `MAX_USERS_PER_INSTANCE`)
- **Faster auto-scaling** - scales up by 2 instances with 180s cooldown (reduced from 300s)
- **More responsive triggers** - CloudWatch alarms with lower thresholds and faster evaluation
- **Additional monitoring** - Request count per target alarm for proactive scaling

### Configuration Options
Set environment variables to customize behavior:
```bash
export MAX_USERS_PER_INSTANCE=50  # Adjust per-instance capacity
```

## 📋 Workshop Flow

1. **Setup** (10 min)
   - Deploy infrastructure with enhanced auto-scaling
   - Verify application handles increased load
   - Monitor scaling behavior in CloudWatch

2. **Load Testing** (15 min)
   - Generate load with multiple browser tabs/devices
   - Observe auto-scaling in action
   - Monitor CloudWatch metrics and alarms

3. **Scaling Optimization** (15 min)
   - Adjust `MAX_USERS_PER_INSTANCE` for different scenarios
   - Test scaling responsiveness
   - Review cost implications of different configurations

## 📁 Project Structure

```
/
├── README.md                              # This file - enhanced overview
├── deploy.sh                              # Automated deployment script
├── main.tf                                # Enhanced Terraform infrastructure
├── user_data_working.sh                   # Updated EC2 bootstrap script
├── app.py                                 # Updated Flask application
└── templates/                             # Updated application templates
    └── error.html                         # Improved error messaging
```

## 🔧 Key Features

- **Configurable capacity** - Up to 25+ concurrent users per instance
- **Responsive auto-scaling** - Faster scaling with multiple instances at once
- **Proactive monitoring** - Multiple CloudWatch alarms for different scenarios
- **Real-time WebSocket** - Shows live connection status across instances
- **Enhanced error handling** - User-friendly messages about scaling activity
- **Cost optimization** - Intelligent scale-down when load decreases

## 📊 Monitoring & Observability

### CloudWatch Alarms
- **High Connection Errors** - Triggers when connection errors exceed 2
- **High Request Count** - Triggers when requests per target exceed 15
- **Low Connections** - Scales down when connections drop below 3

### Key Metrics to Watch
- `RequestCountPerTarget` - Load distribution across instances
- `TargetConnectionErrorCount` - Capacity-related errors
- `ActiveConnectionCount` - Current load level

## 🎯 Scaling Behavior

### Scale Up Triggers
- Connection errors (threshold: 2 errors in 1 minute)
- High request rate (threshold: 15 requests/target in 1 minute)
- Instance capacity reached (25 users per instance by default)

### Scale Down Triggers
- Low connection count (threshold: <3 connections for 15 minutes)
- Sustained low load across multiple evaluation periods

## 💡 Best Practices

1. **Monitor costs** - Auto-scaling can increase costs during high load
2. **Set appropriate limits** - Configure `max_size` in Terraform variables
3. **Test scaling** - Verify behavior under expected load patterns
4. **Review metrics** - Regular monitoring of CloudWatch alarms and metrics

## 📝 Workshop Notes

Track your progress and highlights in [scratch.md](./scratch.md)
