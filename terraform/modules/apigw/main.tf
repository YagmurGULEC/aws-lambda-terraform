# HTTP API
resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # tighten for prod
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

# Integration to Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_function_arn
  payload_format_version = "2.0"
}

# Routes: POST /jobs, GET /jobs, GET /jobs/{id}
resource "aws_apigatewayv2_route" "post_jobs" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_jobs" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_job_id" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /jobs/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Permission so API Gateway can invoke Lambda
resource "aws_lambda_permission" "allow_http_api" {
  statement_id  = "AllowInvokeFromHttpAPI"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# Stage (auto-deploy)
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "Prod"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId",
      httpMethod     = "$context.httpMethod",
      path           = "$context.path",
      status         = "$context.status",
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_apigatewayv2_route" "options_jobs" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "OPTIONS /jobs"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}" # or use MOCK for static response
}
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = 7
}
output "invoke_url" { value = aws_apigatewayv2_stage.prod.invoke_url }
