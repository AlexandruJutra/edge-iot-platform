resource "aws_dynamodb_table" "telemetry" {
  name         = "${var.project_name}-telemetry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "device_id"
  range_key    = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
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
        Resource = aws_dynamodb_table.telemetry.arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "telemetry_to_dynamodb" {
  name        = "${replace(var.project_name, "-", "_")}_telemetry_to_dynamodb"
  description = "Store DHT22 telemetry messages in DynamoDB."
  enabled     = true
  sql         = "SELECT * FROM 'edge/dht22/telemetry'"
  sql_version = "2016-03-23"

  dynamodbv2 {
    role_arn = aws_iam_role.iot_dynamodb.arn

    put_item {
      table_name = aws_dynamodb_table.telemetry.name
    }
  }

  depends_on = [aws_iam_role_policy.iot_dynamodb_put_item]
}
