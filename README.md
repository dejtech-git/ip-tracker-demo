# Real-time IP Tracker for ES Sharing - Workshop Demo

This repository contains two main components for the AWS workshop:

## 📦 Components

### 1. IP Tracker Application
A real-time web application demonstrating AWS infrastructure with auto-scaling capabilities.

**See:** [IP-Tracker-app-spec.md](./IP-Tracker-app-spec.md) for complete application documentation.

### 2. CloudWatch Investigations Demo
Hands-on demonstration of AWS CloudWatch Investigations for AI-assisted troubleshooting.

**See:** [CLOUDWATCH_INVESTIGATIONS_DEMO.md](./CLOUDWATCH_INVESTIGATIONS_DEMO.md) for demo scenarios and instructions.

## 🚀 Quick Start

### Deploy Infrastructure
```bash
terraform init
terraform apply
```

### Access Application
Use the `website_url` output from Terraform:
```
http://ip-tracker-alb-306488846.us-east-1.elb.amazonaws.com/app-x7k9m2n8/
```

## 📋 Workshop Flow

1. **Setup** (15 min)
   - Deploy infrastructure with Terraform
   - Configure CloudWatch Investigations
   - Verify application is running

2. **Demo Scenario 1: Capacity Issue** (20 min)
   - Generate load to reach 3-user limit
   - Trigger 503 errors
   - Use CloudWatch Investigations to identify capacity constraints

3. **Demo Scenario 2: Security Misconfiguration** (20 min)
   - Break service by modifying security group
   - Use CloudWatch Investigations to correlate CloudTrail events
   - Identify root cause and restore service

## 📁 Project Structure

```
Demo1/
├── README.md                              # This file - workshop overview
├── IP-Tracker-app-spec.md                 # Application specifications
├── CLOUDWATCH_INVESTIGATIONS_DEMO.md      # Demo scenarios guide
├── scratch.md                             # Workshop notes and highlights
├── main.tf                                # Terraform infrastructure
├── user_data_working.sh                   # EC2 bootstrap script
└── templates/                             # Application templates
```

## 🔧 Key Features

- **3 concurrent users per instance** - demonstrates capacity limits
- **Auto-scaling** - responds to load changes
- **Real-time WebSocket** - shows live connection status
- **CloudWatch Logs** - system logs for investigations
- **CloudTrail integration** - tracks infrastructure changes

## 📝 Workshop Notes

Track your progress and highlights in [scratch.md](./scratch.md)
