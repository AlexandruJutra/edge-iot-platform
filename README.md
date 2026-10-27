# Edge IoT Platform

A Raspberry Pi monitoring project that collects DHT22 temperature and humidity
readings, sends them to AWS, and displays the latest measurements in a web dashboard.

## How It Works

```text
DHT22 -> Raspberry Pi -> AWS IoT Core -> DynamoDB
																					|
																			 Lambda
																					|
																		 API Gateway
																					|
																 Web dashboard / Grafana
```

- **Sensor:** A Python application reads the DHT22 on GPIO 4 and publishes
	temperature in Celsius and Fahrenheit, humidity, a device ID, and a timestamp.
- **Secure messaging:** MQTT uses device certificates for mutual TLS and publishes
	to `edge/dht22/telemetry`.
- **Storage:** An AWS IoT rule timestamps incoming readings in UTC and stores them
	in an existing DynamoDB table.
- **API:** Lambda exposes stored telemetry as JSON through `GET /telemetry`, usable
	by the dashboard and Grafana's Infinity data source. This endpoint is unauthenticated.
- **Dashboard:** A static site served through CloudFront shows the latest
	temperature, humidity, and reading time. It refreshes every 10 minutes and changes
	the browser tab title when the temperature falls below an adjustable threshold.
	An optional link opens an external Grafana dashboard.

## Automation

GitHub Actions provides two main workflows:

- **Build DHT22 ARM64 image:** Builds the sensor container for the Raspberry Pi and
	publishes it to GitHub Container Registry. Runs manually or when the sensor script changes.
- **Terraform IoT Core:** Supports `plan`, `apply`, `plan-apply`, and `destroy`.
	Deployment provisions AWS resources, connects to the Pi through Tailscale and SSH,
	copies device certificates, and starts the telemetry container. The configured
	publishing interval is 10 minutes. A `plan-apply` run also checks for fresh telemetry.

The deployment workflow reports the website and API URLs in its run summary.

## Requirements

- A Raspberry Pi with Docker, Tailscale, and a DHT22 connected to GPIO 4.
- An AWS account, the existing telemetry DynamoDB table, and the configured S3
	Terraform state bucket.
- GitHub Actions secrets for AWS access, Tailscale OAuth, device SSH access, and
	container registry publishing.

The sensor's AWS IoT endpoint is currently set in [edge/dht22_read.py](edge/dht22_read.py).
The container reads certificates from `/app/certs`; `IOT_PUBLISH_INTERVAL_S` controls
the publishing interval (default: 5 minutes).

## Project Layout

| Directory | Purpose |
| --- | --- |
| [edge/](edge/) | Python sensor publisher |
| [docker/](docker/) | Sensor container image and dependencies |
| [terraform/](terraform/) | AWS infrastructure and dashboard template |
| [lambda/](lambda/) | Telemetry JSON export |
| [tests/](tests/) | Fresh-telemetry verification script |
| [.github/workflows/](.github/workflows/) | Build, deployment, and device workflows |

## Teardown

Run the Terraform workflow with `destroy` to remove Terraform-managed AWS resources.
The DynamoDB table is managed separately and its stored readings are preserved.
Device certificates and private keys must not be committed to Git.
