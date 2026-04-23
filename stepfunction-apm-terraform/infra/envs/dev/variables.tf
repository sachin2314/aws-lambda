variable "lambda_s3_bucket" {
  type        = string
  description = "S3 bucket for Lambda artifacts"
}

variable "lambda_s3_prefix_app" {
  type        = string
  description = "Prefix for app lambda zips (e.g. app_main/)"
}

variable "lambda_s3_prefix_agents" {
  type        = string
  description = "Prefix for agent lambda zips (e.g. sre_agents/)"
}

variable "region" {
  type        = string
  default     = "eu-west-2"
}