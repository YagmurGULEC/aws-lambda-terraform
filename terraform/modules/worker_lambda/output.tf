output "worker_lambda_function_name" {
  description = "The name of the Lambda function"
  value       = aws_lambda_function.worker_lambda.function_name
}

output "worker_lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.worker_lambda.arn
}
