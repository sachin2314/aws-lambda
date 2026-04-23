output "lambda_names" {
  description = "Names of the deployed Lambda functions"
  value       = [for _, v in aws_lambda_function.lambdas : v.function_name]
}
