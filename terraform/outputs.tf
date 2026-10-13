output "iot_endpoint" {
  description = "AWS IoT Core data endpoint (ATS) to use as the MQTT broker host."
  value       = data.aws_iot_endpoint.ats.endpoint_address
}

output "thing_name" {
  description = "Name of the created IoT thing."
  value       = aws_iot_thing.device.name
}

output "certificate_arn" {
  description = "ARN of the device certificate."
  value       = aws_iot_certificate.device.arn
}

output "certs_directory" {
  description = "Local directory containing the generated certificate and keys."
  value       = "${path.module}/${var.certs_output_dir}"
}

# ATS data endpoint for MQTT connections.
data "aws_iot_endpoint" "ats" {
  endpoint_type = "iot:Data-ATS"
}
