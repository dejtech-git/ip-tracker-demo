#!/bin/bash

# IP Tracker Auto-Scaling Deployment Script
# This script deploys the updated infrastructure with improved scaling capabilities

set -e

echo "🚀 Starting IP Tracker Auto-Scaling Deployment..."

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI is not configured. Please configure AWS credentials first."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..."
    terraform init
fi

# Plan the deployment
echo "📋 Planning Terraform deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo ""
echo "📊 Deployment Summary:"
echo "- Increased per-instance user limit from 3 to 25 (configurable)"
echo "- More responsive auto-scaling (2 instances at once, 180s cooldown)"
echo "- Additional CloudWatch alarm for request count per target"
echo "- Improved error messages for better user experience"
echo ""
read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    rm -f tfplan
    exit 1
fi

# Apply the changes
echo "🚀 Applying Terraform changes..."
terraform apply tfplan

# Clean up
rm -f tfplan

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📈 Scaling Improvements:"
echo "- Each EC2 instance can now handle up to 25 concurrent users (configurable)"
echo "- Auto-scaling triggers faster with lower thresholds"
echo "- Scales up by 2 instances at once for better responsiveness"
echo "- New CloudWatch alarm monitors request count per target"
echo ""
echo "🌐 Access your application at:"
terraform output website_url
echo ""
echo "📊 Monitor scaling activity in AWS Console:"
echo "- CloudWatch Alarms: https://console.aws.amazon.com/cloudwatch/home#alarmsV2:"
echo "- Auto Scaling Groups: https://console.aws.amazon.com/ec2/autoscaling/home#AutoScalingGroups:"
echo ""
echo "🔧 To customize the user limit per instance, set the MAX_USERS_PER_INSTANCE environment variable"
echo "   in the launch template or modify the default value in user_data_working.sh"