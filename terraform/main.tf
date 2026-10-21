terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# IoT thing: logical representation of the physical edge device.
# ---------------------------------------------------------------------------
resource "aws_iot_thing" "device" {
  name = var.thing_name
}

# ---------------------------------------------------------------------------
# X.509 certificate used by the device for mutual-TLS MQTT authentication.
# Terraform generates the key pair and certificate for us (active = true).
# ---------------------------------------------------------------------------
resource "aws_iot_certificate" "device" {
  active = true
}

# ---------------------------------------------------------------------------
# IoT policy granting full IoT permissions to the certificate.
# ---------------------------------------------------------------------------
resource "aws_iot_policy" "device" {
  name = "${var.project_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iot:*"
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the certificate (principal).
resource "aws_iot_policy_attachment" "device" {
  policy = aws_iot_policy.device.name
  target = aws_iot_certificate.device.arn
}

# Attach the certificate (principal) to the thing.
resource "aws_iot_thing_principal_attachment" "device" {
  thing     = aws_iot_thing.device.name
  principal = aws_iot_certificate.device.arn
}

# ---------------------------------------------------------------------------
# Fetch the Amazon Root CA so the device can validate the AWS IoT endpoint.
# ---------------------------------------------------------------------------
data "http" "amazon_root_ca1" {
  url = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
}

# ---------------------------------------------------------------------------
# Write the certificate material to local files for the device to use.
# ---------------------------------------------------------------------------
resource "local_sensitive_file" "device_cert" {
  content  = aws_iot_certificate.device.certificate_pem
  filename = "${path.module}/${var.certs_output_dir}/device.pem.crt"
}

resource "local_sensitive_file" "device_private_key" {
  content  = aws_iot_certificate.device.private_key
  filename = "${path.module}/${var.certs_output_dir}/private.pem.key"
}

resource "local_sensitive_file" "device_public_key" {
  content  = aws_iot_certificate.device.public_key
  filename = "${path.module}/${var.certs_output_dir}/public.pem.key"
}

resource "local_file" "root_ca" {
  content  = data.http.amazon_root_ca1.response_body
  filename = "${path.module}/${var.certs_output_dir}/AmazonRootCA1.pem"
}
