#!/bin/bash
# Optimized user_data - assumes AMI has Python, Redis, and app pre-installed
set -e

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
REGION=$(ec2-metadata --availability-zone | cut -d " " -f 2 | sed 's/[a-z]$//')

# Dynamic configuration from Terraform variables
SECRET_PATH="${secret_path}"
REDIS_HOST="${redis_host}"

# Update application environment
cat > /home/ec2-user/ip-tracker/.env << EOF
SECRET_PATH=$SECRET_PATH
REDIS_HOST=$REDIS_HOST
INSTANCE_ID=$INSTANCE_ID
EOF

# Restart application
cd /home/ec2-user/ip-tracker
sudo systemctl restart ip-tracker || {
    # If systemd service doesn't exist, start manually
    sudo -u ec2-user nohup python3 app.py > /var/log/ip-tracker.log 2>&1 &
}

echo "Application configured and started"
