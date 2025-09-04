
# Helpful locals
locals {
  results_bucket_arn = "arn:aws:s3:::${var.athena_results_bucket}"
  results_prefix_arn = "arn:aws:s3:::${var.athena_results_bucket}/${var.athena_results_prefix}*"
}
resource "random_id" "bucket_suffix" {
  byte_length = 4
}


resource "aws_athena_workgroup" "dash_wg" {
  name = "dash-wg"

  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/${var.athena_results_prefix}"
      # If your bucket is SSE-S3, Athena will use it automatically.
      # For SSE-KMS you'd add encryption_configuration here.
    }
  }
}
# Lambda function
resource "aws_lambda_function" "worker_lambda" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"
  image_uri     = var.ecr_repo_url
  memory_size   = 512
  timeout       = 29

  environment {
    variables = {
      GLUE_DATABASE    = "label-studio-crawler-analytics-db"
      TABLE_NAME       = "annotations_parquet"
      ATHENA_OUTPUT    = "s3://${var.athena_results_bucket}/${var.athena_results_prefix}"
      ATHENA_WORKGROUP = aws_athena_workgroup.dash_wg.name
      DYNAMO_TABLE     = var.dynamo_table_name

    }
  }


  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,

  ]
}

resource "aws_lambda_event_source_mapping" "from_sqs" {
  event_source_arn = var.queue_arn # passed from main
  function_name    = aws_lambda_function.worker_lambda.arn
  batch_size       = 1
  enabled          = true
}

