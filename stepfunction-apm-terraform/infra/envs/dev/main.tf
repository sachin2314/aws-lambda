provider "aws" {
  region = "eu-west-2"
}

module "app_main" {
  source = "../../modules/app_main"

  lambda_names         = ["lambdaA", "lambdaB", "lambdaC", "lambdaD", "lambdaE"]
  lambda_s3_bucket     = var.lambda_s3_bucket
  lambda_s3_key_prefix = var.lambda_s3_prefix_app
  region = var.region
}

module "lambda_memory_agent" {
  source = "../../modules/lambda_memory_agent"

  lambda_function_names  = module.app_main.lambda_names
  agent_lambda_s3_bucket = var.lambda_s3_bucket
  agent_lambda_s3_key    = "${var.lambda_s3_prefix_agents}lambda_memory_agent.zip"
}
