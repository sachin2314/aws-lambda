variable "lambda_function_names" {
  type        = list(string)
  description = "Lambda functions to monitor for high memory usage"
}

variable "agent_lambda_s3_bucket" {
  type        = string
  description = "S3 bucket for the agent Lambda zip"
}

variable "agent_lambda_s3_key" {
  type        = string
  description = "S3 key for the agent Lambda zip"
}
