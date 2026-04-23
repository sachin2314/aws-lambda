output "sns_topic_arn" {
  value       = aws_sns_topic.lambda_memory_alarms.arn
  description = "SNS topic for Lambda memory alarms"
}
