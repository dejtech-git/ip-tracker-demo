# Real-time IP Tracker for ES Sharing - Workshop Demo

This repository contains AWS infrastructure and application code for demonstrating CloudWatch Investigations and automated incident response.

## 📦 Components

### 1. IP Tracker Application
A real-time web application demonstrating AWS infrastructure with auto-scaling capabilities.

**See:** [IP-Tracker-app-spec.md](./IP-Tracker-app-spec.md) for complete application documentation.

### 2. CloudWatch Investigations Demo
Hands-on demonstration of AWS CloudWatch Investigations for AI-assisted troubleshooting.

**See:** [CLOUDWATCH_INVESTIGATIONS_DEMO.md](./CLOUDWATCH_INVESTIGATIONS_DEMO.md) for demo scenarios and instructions.

### 3. Automated Incident Response
AI-driven workflow that automatically creates GitHub issues from CloudWatch Investigations, triggering Amazon Q Developer to generate remediation pull requests.

**Flow:** 503 Errors → CloudWatch Investigation → GitHub Issue → Q Developer PR

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with credentials
- Terraform installed (v1.0+)
- GitHub personal access token (optional, for automated issue creation)

### Deploy Infrastructure

1. **Clone and configure:**
```bash
git clone <your-repo-url>
cd Demo1
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed (defaults work fine)
```

2. **Deploy:**
```bash
terraform init
terraform apply
```

3. **Access application:**
```bash
# Get the application URL
terraform output website_url

# Example output:
# http://ip-tracker-alb-<random>.us-east-1.elb.amazonaws.com/app-<random>/
```

**For detailed deployment instructions:** See [DEPLOYMENT_NEW_ACCOUNT.md](./DEPLOYMENT_NEW_ACCOUNT.md)

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
├── README.md                              # This file
├── DEPLOYMENT_NEW_ACCOUNT.md              # Complete deployment guide
├── AMI_SETUP.md                           # Custom AMI optimization guide
├── IP-Tracker-app-spec.md                 # Application specifications
├── CLOUDWATCH_INVESTIGATIONS_DEMO.md      # Demo scenarios guide
├── main.tf                                # Terraform infrastructure
├── cloudwatch_investigation_automation.tf # Investigation automation
├── investigation_deduplication.tf         # DynamoDB deduplication
├── user_data_working.sh                   # EC2 bootstrap (full install)
├── user_data_optimized.sh                 # EC2 bootstrap (AMI-based)
├── terraform.tfvars.example               # Configuration template
├── lambda/                                # Lambda functions
│   ├── start_investigation.py
│   └── create_github_issue.py
└── templates/                             # Application templates
```

## 🔧 Key Features

- **3 concurrent users per instance** - demonstrates capacity limits
- **Auto-scaling** - responds to load changes
- **Real-time WebSocket** - shows live connection status
- **CloudWatch Logs** - system logs for investigations
- **CloudTrail integration** - tracks infrastructure changes
- **Automated incident response** - GitHub issue creation
- **Custom AMI support** - 70% faster instance startup

## ⚡ Performance Optimization

The project supports custom AMI for faster deployments:
- **Standard:** 3-5 minute instance startup
- **Optimized:** 60-90 second instance startup

See [AMI_SETUP.md](./AMI_SETUP.md) for details.

## 🔐 Security Notes

- No credentials are stored in code
- GitHub token stored in AWS Secrets Manager
- Use IAM roles for AWS service access
- Application URL uses random path for obscurity
- Each deployment generates unique ALB DNS and secret path

## 📝 Configuration

### Required Configuration
Copy `terraform.tfvars.example` to `terraform.tfvars` and customize if needed:

```hcl
# Custom AMI (optional - set after creating AMI)
use_custom_ami = false
custom_ami_id  = ""

# Application configuration (defaults work fine)
secret_path      = "app-x7k9m2n8"  # Random path
desired_capacity = 1
min_size         = 1
max_size         = 10
```

### Add GitHub Token (Optional)
For automated GitHub issue creation:

```bash
# Get secret ARN
SECRET_ARN=$(terraform output -raw github_token_secret_arn)

# Add your token
aws secretsmanager put-secret-value \
  --secret-id $SECRET_ARN \
  --secret-string "ghp_your_token_here"
```

## 🧹 Clean Up

```bash
terraform destroy
```

**Note:** Custom AMIs are not deleted by Terraform. Delete manually if created:
```bash
aws ec2 deregister-image --image-id <ami-id>
```

## 📚 Additional Documentation

- [DEPLOYMENT_NEW_ACCOUNT.md](./DEPLOYMENT_NEW_ACCOUNT.md) - Complete deployment guide
- [AMI_SETUP.md](./AMI_SETUP.md) - Custom AMI creation for faster startups
- [CLOUDWATCH_INVESTIGATIONS_DEMO.md](./CLOUDWATCH_INVESTIGATIONS_DEMO.md) - Demo scenarios
- [IP-Tracker-app-spec.md](./IP-Tracker-app-spec.md) - Application specifications

## 🤝 Contributing

This is a workshop demo project. Feel free to fork and customize for your needs.

## 📄 License

This project is provided as-is for educational purposes.
