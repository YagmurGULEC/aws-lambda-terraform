output "queue_url" {
  value = aws_sqs_queue.job_queue.id # <-- this is the QUEUE_URL
}
output "queue_arn" {
  value = aws_sqs_queue.job_queue.arn # <-- this is the QUEUE_ARN
}
