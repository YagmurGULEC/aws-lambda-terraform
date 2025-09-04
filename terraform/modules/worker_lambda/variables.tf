variable "ecr_repo_url" {
  type = string

}
variable "function_name" {
  type = string
}

variable "athena_results_bucket" { default = "my-label-studio-99cc23ce" }
variable "athena_results_prefix" { default = "imported/" }
variable "kms_key_arn" { default = "" } # if your S3 bucket is KMS-encrypted; else leave empty
variable "aws_region" { default = "us-east-1" }

variable "queue_arn" {
  type = string
}

variable "job_table_arn" {
  type = string
}

variable "dynamo_table_name" {
  type = string
}

