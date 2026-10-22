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

variable "grafana_embed_url" {
  description = "Grafana panel/dashboard URL opened from the static website. Empty hides the button."
  type        = string
  default     = "https://lankyjungle1504.grafana.net/public-dashboards/35a0ace6a5cd4c3b99083b3190480bee"
}
