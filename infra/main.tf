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
  package_type  = "Image"
  image_uri     = var.ecr_repo_url
  memory_size   = 512
  timeout       = 15

  #   layers = [aws_lambda_layer_version.numpy.arn]


  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    # aws_lambda_layer_version.numpy
  ]
}

# Outputs
output "function_name" {
  value = aws_lambda_function.matrix_mul.function_name
}

output "function_arn" {
  value = aws_lambda_function.matrix_mul.arn
}


