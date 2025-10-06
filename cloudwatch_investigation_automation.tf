# CloudWatch Investigation Automation - GitHub Integration
# This creates an automated workflow: 503 Errors → Investigation → GitHub Issue → Q Developer PR

# Store GitHub token in Secrets Manager
resource "aws_secretsmanager_secret" "github_token" {
  name        = "ip-tracker-github-token"
  description = "GitHub Personal Access Token for creating issues"
}

# Note: You need to manually add the token value after creation:
# aws secretsmanager put-secret-value --secret-id ip-tracker-github-token --secret-string "your-github-token"

# CloudWatch Alarm that triggers investigation
resource "aws_cloudwatch_metric_alarm" "investigation_trigger" {
  alarm_name          = "ip-tracker-503-investigation-trigger"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Triggers CloudWatch Investigation when 503 errors detected"
  
  dimensions = {
    LoadBalancer = aws_lb.ip_tracker.arn_suffix
  }
  
  # This will trigger SNS which starts investigation manually
  # Note: Direct investigation trigger from alarm is not yet supported in Terraform
  alarm_actions = [aws_sns_topic.investigation_trigger.arn]
}

# SNS Topic for investigation trigger
resource "aws_sns_topic" "investigation_trigger" {
  name = "ip-tracker-investigation-trigger"
}

# SNS subscription to Lambda for starting investigation
resource "aws_sns_topic_subscription" "start_investigation" {
  topic_arn = aws_sns_topic.investigation_trigger.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.start_investigation.arn
}

# Lambda to start CloudWatch Investigation
resource "aws_lambda_function" "start_investigation" {
  filename      = "lambda_start_investigation.zip"
  function_name = "ip-tracker-start-investigation"
  role          = aws_iam_role.lambda_investigation.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  
  environment {
    variables = {
      ALB_ARN        = aws_lb.ip_tracker.arn
      TARGET_GROUP_ARN = aws_lb_target_group.ip_tracker.arn
    }
  }
}

# Lambda permission for SNS to invoke
resource "aws_lambda_permission" "sns_invoke_start_investigation" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_investigation.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.investigation_trigger.arn
}

# EventBridge rule for investigation completion
resource "aws_cloudwatch_event_rule" "investigation_complete" {
  name        = "ip-tracker-investigation-complete"
  description = "Triggers when CloudWatch Investigation completes"
  
  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Investigation State Change"]
    detail = {
      status = ["COMPLETED"]
    }
  })
}

# EventBridge target - Lambda to create GitHub issue
resource "aws_cloudwatch_event_target" "create_github_issue" {
  rule      = aws_cloudwatch_event_rule.investigation_complete.name
  target_id = "CreateGitHubIssue"
  arn       = aws_lambda_function.create_github_issue.arn
}

# Lambda to create GitHub issue from investigation results
resource "aws_lambda_function" "create_github_issue" {
  filename      = "lambda_github_issue.zip"
  function_name = "ip-tracker-investigation-to-github"
  role          = aws_iam_role.lambda_github.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 60
  
  environment {
    variables = {
      GITHUB_TOKEN_SECRET = aws_secretsmanager_secret.github_token.arn
      GITHUB_REPO_OWNER   = "dejtech-git"
      GITHUB_REPO_NAME    = "ip-tracker-demo"
    }
  }
}

# Lambda permission for EventBridge to invoke
resource "aws_lambda_permission" "eventbridge_invoke_github" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_github_issue.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.investigation_complete.arn
}

# IAM role for investigation Lambda
resource "aws_iam_role" "lambda_investigation" {
  name = "ip-tracker-lambda-investigation-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM policy for investigation Lambda
resource "aws_iam_role_policy" "lambda_investigation_policy" {
  name = "investigation-permissions"
  role = aws_iam_role.lambda_investigation.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:StartInvestigation",
          "cloudwatch:DescribeInvestigation"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM role for GitHub Lambda
resource "aws_iam_role" "lambda_github" {
  name = "ip-tracker-lambda-github-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM policy for GitHub Lambda
resource "aws_iam_role_policy" "lambda_github_policy" {
  name = "github-permissions"
  role = aws_iam_role.lambda_github.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.github_token.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeInvestigation",
          "cloudwatch:GetInvestigationFindings"
        ]
        Resource = "*"
      }
    ]
  })
}

# Outputs
output "github_token_secret_arn" {
  value       = aws_secretsmanager_secret.github_token.arn
  description = "ARN of the GitHub token secret - add token value manually"
}

output "investigation_alarm_name" {
  value       = aws_cloudwatch_metric_alarm.investigation_trigger.alarm_name
  description = "CloudWatch alarm that triggers investigations"
}
