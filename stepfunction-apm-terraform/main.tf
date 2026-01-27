terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# IAM Role for Lambdas
resource "aws_iam_role" "lambda_role" {
  name = "lambda_basic_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package Lambda function
locals {
  lambda_dirs = {
    LambdaA = "lambdaA"
    LambdaB = "lambdaB"
    LambdaC = "lambdaC"
    LambdaD = "lambdaD"
    LambdaE = "lambdaE"
  }
}

resource "aws_lambda_function" "lambdas" {
  for_each = local.lambda_dirs

  function_name = each.key
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.handler"
  runtime       = "python3.12"

  filename         = "${each.value}.zip"
  source_code_hash = filebase64sha256("${each.value}.zip")
}

# IAM Role for Step Functions
resource "aws_iam_role" "sf_role" {
  name = "stepfunction_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action = "sts:AssumeRole"
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

# Step Function 2
resource "aws_sfn_state_machine" "sf2" {
  name     = "StepFunction2"
  role_arn = aws_iam_role.sf_role.arn

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
# Step Function 1
resource "aws_sfn_state_machine" "sf1" {
  name     = "StepFunction1"
  role_arn = aws_iam_role.sf_role.arn

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