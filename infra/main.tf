terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
    random  = { source = "hashicorp/random", version = "~> 3.0" }
  }
}
provider "aws" {
  region  = "us-east-1"
  profile = "default" # Use your AWS profile or set up credentials in ~/.aws/credentials
}


# provider "aws" {
#   region                      = "us-east-1"
#   access_key                  = "test"
#   secret_key                  = "test"
#   s3_use_path_style           = true
#   skip_credentials_validation = true
#   skip_requesting_account_id  = true

#   endpoints {
#     iam    = "http://localhost:4566"
#     s3     = "http://localhost:4566"
#     lambda = "http://localhost:4566"
#     logs   = "http://localhost:4566"
#     sts    = "http://localhost:4566"
#   }
# }
resource "random_id" "bucket_suffix" {
  byte_length = 4
}
# Create the function zip (this will be more reliable than external script)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda_handler"
  output_path = "${path.module}/../function.zip"

  # Force recreation when any .py file changes
  depends_on = [
    # Add any dependencies that should trigger rebuild
  ]
}

# Bucket for code & layers
resource "aws_s3_bucket" "artifacts" {
  bucket = "tf-lambda-artifacts-${random_id.bucket_suffix.hex}"
}

# Upload function code - force update when content changes
resource "aws_s3_object" "function_zip" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "function-${data.archive_file.lambda_zip.output_md5}.zip" # Include hash in key
  source = data.archive_file.lambda_zip.output_path
  etag   = data.archive_file.lambda_zip.output_md5
}

# Upload your prebuilt numpy layer zip
resource "aws_s3_object" "numpy_layer_zip" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "numpy-layer-${filemd5("${path.module}/../numpy-layer.zip")}.zip" # Include hash in key
  source = "${path.module}/../numpy-layer.zip"
  etag   = filemd5("${path.module}/../numpy-layer.zip")
}

# Create layer
resource "aws_lambda_layer_version" "numpy" {
  layer_name               = "numpy"
  s3_bucket                = aws_s3_bucket.artifacts.id
  s3_key                   = aws_s3_object.numpy_layer_zip.key
  compatible_runtimes      = ["python3.10"]
  compatible_architectures = ["x86_64"]
  description              = "NumPy layer"

  # Force new version when layer content changes
  source_code_hash = filebase64sha256("${path.module}/../numpy-layer.zip")
}

# IAM role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "matrix_mul" {
  function_name = "matrix-mul"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.10"
  handler       = "handler.lambda_handler" # file.function
  architectures = ["x86_64"]

  s3_bucket        = aws_s3_bucket.artifacts.id
  s3_key           = aws_s3_object.function_zip.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = 512
  timeout     = 15

  layers = [aws_lambda_layer_version.numpy.arn]

  #   environment {
  #     variables = {
  #       PYTHONPATH = "/opt/python"
  #     }
  #   }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_lambda_layer_version.numpy
  ]
}

# Outputs
output "function_name" {
  value = aws_lambda_function.matrix_mul.function_name
}

output "function_arn" {
  value = aws_lambda_function.matrix_mul.arn
}

output "layer_arn" {
  value = aws_lambda_layer_version.numpy.arn
}
