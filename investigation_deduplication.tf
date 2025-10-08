# DynamoDB table for investigation deduplication
resource "aws_dynamodb_table" "investigations" {
  name         = "ip-tracker-investigations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "resource_arn"

  attribute {
    name = "resource_arn"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "IP Tracker Investigations"
  }
}

# Add DynamoDB permissions to investigation Lambda role
resource "aws_iam_role_policy" "lambda_investigation_dynamodb" {
  name = "dynamodb-permissions"
  role = aws_iam_role.lambda_investigation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.investigations.arn
      }
    ]
  })
}

output "investigations_table_name" {
  value       = aws_dynamodb_table.investigations.name
  description = "DynamoDB table for investigation deduplication"
}
