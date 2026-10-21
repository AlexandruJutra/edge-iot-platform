

# ---------------------------------------------------------------------------
# GET /telemetry -> Lambda "GrafanaJsonExport" -> DynamoDB, consumed by
# Grafana's Infinity data source.
# ---------------------------------------------------------------------------
resource "random_password" "grafana_json_export_api_key" {
  length  = 32
  special = false
}

data "archive_file" "grafana_json_export" {
  type        = "zip"
  output_path = "${path.module}/grafana_json_export.zip"

  source {
    content  = file("${path.module}/../lambda/lamba_export_to_grafana.py")
    filename = "lambda_function.py"
  }
}

resource "aws_cloudwatch_log_group" "grafana_json_export" {
  name              = "/aws/lambda/GrafanaJsonExport"
  retention_in_days = 14
}

resource "aws_iam_role" "grafana_json_export" {
  name = "GrafanaJsonExport-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "grafana_json_export" {
  name = "GrafanaJsonExport-policy"
  role = aws_iam_role.grafana_json_export.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = data.aws_dynamodb_table.telemetry.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.grafana_json_export.arn}:*"
      }
    ]
  })
}

resource "aws_lambda_function" "grafana_json_export" {
  function_name    = "GrafanaJsonExport"
  role             = aws_iam_role.grafana_json_export.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.grafana_json_export.output_path
  source_code_hash = data.archive_file.grafana_json_export.output_base64sha256
  timeout          = 15

  environment {
    variables = {
      TABLE_NAME        = data.aws_dynamodb_table.telemetry.name
      DEFAULT_DEVICE_ID = var.thing_name
      API_KEY           = random_password.grafana_json_export_api_key.result
    }
  }

  depends_on = [
    aws_iam_role_policy.grafana_json_export,
    aws_cloudwatch_log_group.grafana_json_export,
  ]
}

resource "aws_apigatewayv2_api" "grafana_json_export" {
  name          = "GrafanaJsonExport"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "grafana_json_export" {
  api_id                 = aws_apigatewayv2_api.grafana_json_export.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.grafana_json_export.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "grafana_json_export" {
  api_id    = aws_apigatewayv2_api.grafana_json_export.id
  route_key = "GET /telemetry"
  target    = "integrations/${aws_apigatewayv2_integration.grafana_json_export.id}"
}

resource "aws_apigatewayv2_stage" "grafana_json_export" {
  api_id      = aws_apigatewayv2_api.grafana_json_export.id
  name        = "dev"
  auto_deploy = true
}

resource "aws_lambda_permission" "grafana_json_export" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.grafana_json_export.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.grafana_json_export.execution_arn}/*/*"
}

output "grafana_json_export_url" {
  description = "GET endpoint for Grafana's Infinity data source. Send the API key in the X-Api-Key header."
  value       = "${aws_apigatewayv2_stage.grafana_json_export.invoke_url}/telemetry"
}

output "grafana_json_export_api_key" {
  description = "Value for the X-Api-Key header. Retrieve with: terraform output -raw grafana_json_export_api_key"
  value       = random_password.grafana_json_export_api_key.result
  sensitive   = true
}
