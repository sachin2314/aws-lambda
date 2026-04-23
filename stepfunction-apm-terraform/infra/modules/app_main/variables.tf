variable "lambda_names" {
  type        = list(string)
  description = "Logical names for the Lambda functions (e.g. lambdaA, lambdaB...)"
}

variable "lambda_s3_bucket" {
  type        = string
  description = "S3 bucket where Lambda zips are stored"
}

variable "lambda_s3_key_prefix" {
  type        = string
  description = "Prefix in S3 for Lambda zips (e.g. app_main/)"
}

variable "region" {
  type        = string
  description = "AWS region for resource ARNs"
}