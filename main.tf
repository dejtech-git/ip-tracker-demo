provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "min_size" {
  default = 1
}

variable "max_size" {
  default = 10
}

variable "desired_capacity" {
  default = 2
}

variable "secret_path" {
  default = "app-x7k9m2n8"
  description = "Random path to obscure the application URL"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Custom AMI configuration
variable "use_custom_ami" {
  default     = false
  description = "Use custom AMI with pre-installed app (set to true after creating AMI)"
}

variable "custom_ami_id" {
  default     = ""
  description = "Custom AMI ID with IP Tracker pre-installed (leave empty to use base Amazon Linux)"
}

locals {
  ami_id = var.use_custom_ami && var.custom_ami_id != "" ? var.custom_ami_id : data.aws_ami.amazon_linux.id
  user_data_file = var.use_custom_ami && var.custom_ami_id != "" ? "user_data_optimized.sh" : "user_data_working.sh"
}

# VPC Configuration
resource "aws_vpc" "ip_tracker_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "IPTracker-VPC"
  }
}

resource "aws_internet_gateway" "ip_tracker_igw" {
  vpc_id = aws_vpc.ip_tracker_vpc.id

  tags = {
    Name = "IPTracker-IGW"
  }
}

# Public Subnets for ALB and EC2
resource "aws_subnet" "public_subnets" {
  count             = 2
  vpc_id            = aws_vpc.ip_tracker_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "IPTracker-Public-Subnet-${count.index + 1}"
  }
}

# Private Subnets for ElastiCache
resource "aws_subnet" "private_subnets" {
  count             = 2
  vpc_id            = aws_vpc.ip_tracker_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "IPTracker-Private-Subnet-${count.index + 1}"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ip_tracker_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ip_tracker_igw.id
  }

  tags = {
    Name = "IPTracker-Public-RT"
  }
}

resource "aws_route_table_association" "public_rta" {
  count          = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name = "ip-tracker-alb-sg"
  vpc_id = aws_vpc.ip_tracker_vpc.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name = "ip-tracker-ec2-sg"
  vpc_id = aws_vpc.ip_tracker_vpc.id
  
  ingress {
    from_port       = 8800
    to_port         = 8800
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "redis_sg" {
  name = "ip-tracker-redis-sg"
  vpc_id = aws_vpc.ip_tracker_vpc.id
  
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
}

# ElastiCache Subnet Group (Private Subnets)
resource "aws_elasticache_subnet_group" "ip_tracker" {
  name       = "ip-tracker-cache-subnet"
  subnet_ids = aws_subnet.private_subnets[*].id
}

# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "ip_tracker" {
  replication_group_id       = "ip-tracker-redis"
  description                = "Redis cluster for IP tracker sessions"
  
  node_type                  = "cache.t3.micro"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  num_cache_clusters         = 1
  
  subnet_group_name          = aws_elasticache_subnet_group.ip_tracker.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false
}

# Store Redis endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "redis_endpoint" {
  name  = "/ip-tracker/redis-endpoint"
  type  = "String"
  value = aws_elasticache_replication_group.ip_tracker.primary_endpoint_address
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "ip-tracker-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for SSM and CloudWatch access
resource "aws_iam_role_policy" "ec2_ssm_policy" {
  name = "ip-tracker-ssm-cloudwatch-policy"
  role = aws_iam_role.ec2_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/ip-tracker/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/ec2/ip-tracker/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ip-tracker-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Launch Template
resource "aws_launch_template" "ip_tracker" {
  name_prefix   = "ip-tracker-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }
  
  user_data = local.user_data_file == "user_data_optimized.sh" ? base64encode(templatefile("user_data_optimized.sh", {
    secret_path = var.secret_path
    redis_host  = aws_elasticache_replication_group.ip_tracker.primary_endpoint_address
  })) : base64encode(file("user_data_working.sh"))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "IPTracker-Instance"
    }
  }
}

# Application Load Balancer
resource "aws_lb" "ip_tracker" {
  name               = "ip-tracker-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id
}

# Target Group with least connections
resource "aws_lb_target_group" "ip_tracker" {
  name     = "ip-tracker-tg"
  port     = 8800
  protocol = "HTTP"
  vpc_id   = aws_vpc.ip_tracker_vpc.id
  
  load_balancing_algorithm_type = "least_outstanding_requests"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  stickiness {
    enabled = true
    type    = "lb_cookie"
    cookie_duration = 86400
  }
}

resource "aws_lb_listener" "ip_tracker" {
  load_balancer_arn = aws_lb.ip_tracker.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "ip_tracker" {
  listener_arn = aws_lb_listener.ip_tracker.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_tracker.arn
  }

  condition {
    path_pattern {
      values = ["/${var.secret_path}", "/${var.secret_path}/*"]
    }
  }
}

# WebSocket support for real-time updates
resource "aws_lb_listener_rule" "websocket" {
  listener_arn = aws_lb_listener.ip_tracker.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ip_tracker.arn
  }

  condition {
    path_pattern {
      values = ["/${var.secret_path}/socket.io/*"]
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ip_tracker" {
  name                = "ip-tracker-asg"
  vpc_zone_identifier = aws_subnet.public_subnets[*].id
  target_group_arns   = [aws_lb_target_group.ip_tracker.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity
  
  launch_template {
    id      = aws_launch_template.ip_tracker.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "IPTracker-ASG-Instance"
    propagate_at_launch = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "ip-tracker-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ip_tracker.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "ip-tracker-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ip_tracker.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_connections" {
  alarm_name          = "ip-tracker-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetConnectionErrorCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Scale up when connection errors increase (5 per instance)"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.ip_tracker.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "low_connections" {
  alarm_name          = "ip-tracker-low-connections"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "ActiveConnectionCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Scale down when connections are low (under 5)"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  
  dimensions = {
    LoadBalancer = aws_lb.ip_tracker.arn_suffix
  }
}

output "website_url" {
  value = "http://${aws_lb.ip_tracker.dns_name}/${var.secret_path}/"
}

output "load_balancer_dns" {
  value = aws_lb.ip_tracker.dns_name
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.ip_tracker.primary_endpoint_address
}

output "vpc_id" {
  value = aws_vpc.ip_tracker_vpc.id
}