variable "function_name" {}
variable "zip_path" {}
variable "handler" {}

variable "job_table_name" {}
variable "job_table_arn" {} # <- Add this to pass from the DynamoDB module

variable "queue_url" {}
variable "queue_arn" {} # <- Add this to pass from the SQS module
