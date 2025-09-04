
locals {
  dynamo_table_name = "job-status-table"
}
module "job_queue" {
  source     = "./modules/sqs"
  queue_name = "my-job-queue"

}

module "job_table" {
  source     = "./modules/dynamodb"
  table_name = local.dynamo_table_name
}
module "producer_lambda" {
  source        = "./modules/producer_lambda"
  function_name = "unified-api"
  zip_path      = abspath("${path.module}/../producer_lambda.zip")
  handler       = "handler.unified_api_handler"

  job_table_name = module.job_table.table_name
  job_table_arn  = module.job_table.table_arn
  queue_url      = module.job_queue.queue_url
  queue_arn      = module.job_queue.queue_arn
}
module "worker_lambda" {
  source            = "./modules/worker_lambda"
  function_name     = "data-processor"
  ecr_repo_url      = var.ecr_repo_url
  queue_arn         = module.job_queue.queue_arn
  job_table_arn     = module.job_table.table_arn
  dynamo_table_name = local.dynamo_table_name

}

module "apigw" {
  source               = "./modules/apigw"
  api_name             = "jobs-api"
  lambda_function_arn  = module.producer_lambda.function_arn
  lambda_function_name = module.producer_lambda.function_name
}

output "api_base_url" {
  value = module.apigw.invoke_url
}
