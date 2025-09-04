resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_worker_permissions" {
  name = "${var.function_name}-inline-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs
      {
        Sid    = "CWLogs",
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },

      # SQS
      {
        Sid    = "SQSConsume",
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = var.queue_arn
      },

      # DynamoDB
      {
        Sid      = "DynamoDBUpdateStatus",
        Effect   = "Allow",
        Action   = ["dynamodb:UpdateItem"],
        Resource = var.job_table_arn
      },

      # Athena Basic
      {
        Sid    = "AthenaBasics",
        Effect = "Allow",
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetWorkGroup",
          "athena:ListWorkGroups",
          "athena:GetNamedQuery",
          "athena:ListNamedQueries"
        ],
        Resource = "*"
      },

      # Glue Catalog Read
      {
        Sid    = "GlueCatalogRead",
        Effect = "Allow",
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:GetDataCatalogEncryptionSettings"
        ],
        Resource = "*"
      },

      # Glue Catalog Write
      {
        Sid    = "GlueCatalogWriteForCTAS",
        Effect = "Allow",
        Action = [
          "glue:CreateTable",
          "glue:DeleteTable",
          "glue:UpdateTable"
        ],
        Resource = "*"
      },

      # S3 Bucket Location
      {
        Sid      = "S3GetBucketLocation",
        Effect   = "Allow",
        Action   = ["s3:GetBucketLocation"],
        Resource = "arn:aws:s3:::*"
      },

      # S3 List Bucket - Athena results bucket
      {
        Sid      = "S3ListBucketResults",
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::${var.athena_results_bucket}"
      },

      # S3 List Bucket - crawler bucket
      {
        Sid      = "S3ListCrawlerBucket",
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::label-studio-crawler-bucket"
      },

      # S3 Read/Write to crawler prefix
      {
        Sid      = "S3RWCrawlerPrefix",
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject"],
        Resource = "arn:aws:s3:::label-studio-crawler-bucket/Annotations_parquet/*"
      },

      # S3 RW all under Athena results bucket (optional)
      {
        Sid      = "S3RWAllUnderBucket",
        Effect   = "Allow",
        Action   = ["s3:GetObject", "s3:PutObject"],
        Resource = "arn:aws:s3:::${var.athena_results_bucket}/*"
      },
      {
        Sid    = "AthenaPermissions",
        Effect = "Allow",
        Action = [
          "athena:GetWorkGroup",
          "athena:StartQueryExecution",
          "athena:GetQueryResults",
          "athena:GetQueryExecution",
          "glue:GetDatabase",
          "glue:GetTable",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = "*"
      }
    ]
  })
}
