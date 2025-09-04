resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  zip_path = var.zip_path
  zip_md5  = filemd5(local.zip_path)
  zip_b64  = filebase64sha256(local.zip_path)
}

# Bucket for code & layers
resource "aws_s3_bucket" "artifacts" {
  bucket = "tf-lambda-artifacts-${random_id.bucket_suffix.hex}"
}
# Upload function code - force update when content changes
resource "aws_s3_object" "function_zip" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "function-${local.zip_md5}.zip" # Include hash in key
  source = local.zip_path
  etag   = local.zip_b64
}


resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.10"
  handler       = var.handler
  architectures = ["x86_64"]

  s3_bucket        = aws_s3_bucket.artifacts.id
  s3_key           = aws_s3_object.function_zip.key
  source_code_hash = local.zip_md5

  memory_size = 512
  timeout     = 15
  environment {
    variables = {
      JOB_TABLE = var.job_table_name
      QUEUE_URL = var.queue_url
    }
  }



  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    # aws_lambda_layer_version.numpy
  ]
}



