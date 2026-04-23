resource "aws_sns_topic" "lambda_memory_alarms" {
  name = "lambda-memory-alarms"
}

resource "aws_iam_role" "agent_lambda_role" {
  name = "lambda-memory-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "agent_lambda_policy" {
  name = "lambda-memory-agent-policy"
  role = aws_iam_role.agent_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunctionConfiguration"
        ]
        Resource = "arn:aws:lambda:*:*:function:*"
      }
    ]
  })
}

resource "aws_lambda_function" "lambda_memory_agent" {
  function_name = "lambda-memory-agent"
  role          = aws_iam_role.agent_lambda_role.arn
  handler       = "agent_lambda_code.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256

  s3_bucket = var.agent_lambda_s3_bucket
  s3_key    = var.agent_lambda_s3_key

  environment {
    variables = {
      DIAG_WINDOW_MINUTES = "15"
      LOG_WINDOW_MINUTES  = "15"
    }
  }
}

resource "aws_lambda_permission" "sns_invoke_agent" {
  statement_id  = "AllowSNSToInvokeAgent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_memory_agent.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.lambda_memory_alarms.arn
}

resource "aws_sns_topic_subscription" "lambda_memory_agent_sub" {
  topic_arn = aws_sns_topic.lambda_memory_alarms.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_memory_agent.arn
}

resource "aws_cloudwatch_metric_alarm" "lambda_memory_high" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "LambdaMemoryHigh-${each.value}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 80
  alarm_description   = "Lambda ${each.value} memory usage >= 80%"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m1"
    return_data = false

    metric {
      metric_name = "MaxMemoryUsed"
      namespace   = "AWS/Lambda"
      period      = 60
      stat        = "Maximum"

      dimensions = {
        FunctionName = each.value
      }
    }
  }

  metric_query {
    id          = "m2"
    return_data = false

    metric {
      metric_name = "MemorySize"
      namespace   = "AWS/Lambda"
      period      = 60
      stat        = "Maximum"

      dimensions = {
        FunctionName = each.value
      }
    }
  }

  metric_query {
    id          = "e1"
    expression  = "m1 / m2 * 100"
    label       = "MemoryUsagePercent"
    return_data = true
  }

  alarm_actions = [
    aws_sns_topic.lambda_memory_alarms.arn
  ]
}
