variable "aws_region" {
  description = "AWS region where the IoT resources are created."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefix used to name the IoT thing, policy and certificate resources."
  type        = string
  default     = "edge-dht22"
}

variable "thing_name" {
  description = "Name of the AWS IoT thing representing the edge device."
  type        = string
  default     = "edge-dht22-sensor"
}

variable "certs_output_dir" {
  description = "Local directory where the generated device certificate and keys are written."
  type        = string
  default     = "certs"
}
