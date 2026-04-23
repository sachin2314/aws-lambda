############################################
# IAM ROLE FOR LAMBDAS
############################################

resource "aws_iam_role" "lambda_role" {
  name = "app-main-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

############################################
# SSM POLICY
############################################

resource "aws_ssm_parameter" "app_config" {
  name  = "/demo/app/config"
  type  = "String"
  value = "my-demo-config-value"
}

resource "aws_iam_policy" "lambda_ssm_policy" {
  name        = "lambda_ssm_policy"
  description = "Allow Lambda to read SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ]
      Resource = aws_ssm_parameter.app_config.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ssm_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ssm_policy.arn
}

############################################
# DYNAMODB TABLE + POLICY
############################################

resource "aws_dynamodb_table" "demo_table" {
  name         = "DemoTable"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "pk"
  range_key = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Project     = "application-signals-demo"
  }
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "Allow Lambda to write to DynamoDB DemoTable"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.demo_table.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

############################################
# S3 POLICY
############################################

resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy"
  description = "Allow Lambda to list S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:ListAllMyBuckets"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

############################################
# LAMBDA FUNCTIONS (A–E)
############################################

resource "aws_lambda_function" "lambdas" {
  for_each = toset(var.lambda_names)

  function_name = each.key
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"

  s3_bucket = var.lambda_s3_bucket
  s3_key    = "${var.lambda_s3_key_prefix}${each.key}.zip"

  tracing_config {
    mode = "Active"
  }
}

############################################
# STEP FUNCTION IAM ROLE
############################################

resource "aws_iam_role" "sf_role" {
  name = "stepfunction_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sf_policy" {
  role       = aws_iam_role.sf_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSStepFunctionsFullAccess"
}

resource "aws_iam_role_policy_attachment" "sf_events" {
  role       = aws_iam_role.sf_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchEventsFullAccess"
}

resource "aws_iam_role_policy_attachment" "sf_logs" {
  role       = aws_iam_role.sf_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy" "sf_invoke_lambda" {
  name = "sf_invoke_lambda"
  role = aws_iam_role.sf_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["lambda:InvokeFunction"]
      Resource = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:*"
    }]
  })
}

############################################
# STEP FUNCTION 2
############################################

resource "aws_sfn_state_machine" "sf2" {
  name     = "StepFunction2"
  role_arn = aws_iam_role.sf_role.arn

  tracing_configuration { enabled = true }

  definition = jsonencode({
    StartAt = "LambdaD"
    States = {
      LambdaD = {
        Type     = "Task"
        Resource = aws_lambda_function.lambdas["LambdaD"].arn
        Next     = "LambdaE"
      }
      LambdaE = {
        Type     = "Task"
        Resource = aws_lambda_function.lambdas["LambdaE"].arn
        End      = true
      }
    }
  })
}

############################################
# STEP FUNCTION 1
############################################

resource "aws_sfn_state_machine" "sf1" {
  name     = "StepFunction1"
  role_arn = aws_iam_role.sf_role.arn

  tracing_configuration { enabled = true }

  definition = jsonencode({
    StartAt = "LambdaA"
    States = {
      LambdaA = {
        Type     = "Task"
        Resource = aws_lambda_function.lambdas["LambdaA"].arn
        Next     = "LambdaB"
      }
      LambdaB = {
        Type     = "Task"
        Resource = aws_lambda_function.lambdas["LambdaB"].arn
        Next     = "LambdaC"
      }
      LambdaC = {
        Type     = "Task"
        Resource = aws_lambda_function.lambdas["LambdaC"].arn
        Next     = "CallStepFunction2"
      }
      CallStepFunction2 = {
        Type     = "Task"
        Resource = "arn:aws:states:::states:startExecution.sync"
        Parameters = {
          StateMachineArn = aws_sfn_state_machine.sf2.arn
          Input           = { "value.$" = "$" }
        }
        End = true
      }
    }
  })
}

variable "region" {
  type = string
}