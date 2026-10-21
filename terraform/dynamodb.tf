# The table holds production data and is managed outside Terraform, so
# destroy never touches it. Drop it from state without deleting it.
removed {
  from = aws_dynamodb_table.telemetry

  lifecycle {
    destroy = false
  }
}

data "aws_dynamodb_table" "telemetry" {
  name = "${var.project_name}-telemetry-DB"
}

resource "aws_iam_role" "iot_dynamodb" {
  name = "${var.project_name}-iot-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_dynamodb_put_item" {
  name = "${var.project_name}-iot-dynamodb-put-item"
  role = aws_iam_role.iot_dynamodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = data.aws_dynamodb_table.telemetry.arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "telemetry_to_dynamodb" {
  name        = "${replace(var.project_name, "-", "_")}_telemetry_to_dynamodb"
  description = "Store DHT22 telemetry messages in DynamoDB."
  enabled     = true
  # Override the device-supplied timestamp with AWS IoT's own clock, formatted
  # as a human-readable ISO-8601 UTC string (not local time: avoids DST jumps
  # that would break the range key's sort order for time-range queries).
  sql         = <<-SQL
    SELECT *, parse_time("yyyy-MM-dd'T'HH:mm:ss'Z'", timestamp()) AS timestamp FROM 'edge/dht22/telemetry'
  SQL
  sql_version = "2016-03-23"

  dynamodbv2 {
    role_arn = aws_iam_role.iot_dynamodb.arn

    put_item {
      table_name = data.aws_dynamodb_table.telemetry.name
    }
  }

  # Log a failed put_item (e.g. key type mismatch, missing table) straight to
  # CloudWatch, independent of the account-wide IoT logging level.
  error_action {
    cloudwatch_logs {
      role_arn       = aws_iam_role.iot_rule_errors.arn
      log_group_name = aws_cloudwatch_log_group.telemetry_rule_errors.name
    }
  }

  depends_on = [aws_iam_role_policy.iot_dynamodb_put_item, aws_iam_role_policy.iot_rule_errors]
}

resource "aws_cloudwatch_log_group" "telemetry_rule_errors" {
  name              = "/aws/iot/${var.project_name}-telemetry-errors"
  retention_in_days = 14
}

resource "aws_iam_role" "iot_rule_errors" {
  name = "${var.project_name}-iot-rule-errors-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_rule_errors" {
  name = "${var.project_name}-iot-rule-errors-policy"
  role = aws_iam_role.iot_rule_errors.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.telemetry_rule_errors.arn}:*"
      }
    ]
  })
}
