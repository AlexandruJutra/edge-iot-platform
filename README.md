# Edge → AWS IoT Core (DHT22)

Small Terraform project that provisions an AWS IoT Core **thing**, an X.509
**certificate** for MQTT (mutual TLS) and an IoT **policy** with full IoT
permissions. The Python edge script reads a DHT22 sensor and publishes
temperature + humidity to AWS IoT Core.

## Layout

```
edge/        Python sensor publisher (runs on the Raspberry Pi / edge device)
terraform/   AWS IoT Core infrastructure
```

## 1. Provision AWS IoT Core

```bash
cd terraform
terraform init
terraform apply
```

Terraform writes the device certificate, private key and Amazon Root CA into
`terraform/certs/` and prints the MQTT endpoint:

```bash
terraform output iot_endpoint
```

> The certificate/keys and `*.tfstate` are git-ignored because they are secrets.

## 2. Run the edge publisher

On the edge device (where the DHT22 is wired to GPIO 4 / BCM 4):

```bash
cd edge
export IOT_ENDPOINT="$(cd ../terraform && terraform output -raw iot_endpoint)"
python dht22_read.py
```

### Configuration (environment variables)

| Variable                | Default                               | Description                         |
| ----------------------- | ------------------------------------- | ----------------------------------- |
| `IOT_ENDPOINT`          | _(required)_                          | AWS IoT ATS data endpoint           |
| `IOT_CLIENT_ID`         | `edge-dht22-sensor`                   | MQTT client id                      |
| `IOT_TOPIC`             | `edge/dht22/telemetry`                | MQTT topic to publish to            |
| `IOT_CERT_PATH`         | `../terraform/certs/device.pem.crt`   | Device certificate                  |
| `IOT_PRIVATE_KEY_PATH`  | `../terraform/certs/private.pem.key`  | Device private key                  |
| `IOT_ROOT_CA_PATH`      | `../terraform/certs/AmazonRootCA1.pem`| Amazon Root CA                      |
| `IOT_PUBLISH_INTERVAL_S`| `5`                                   | Seconds between publishes           |

## 3. Verify

In the AWS Console → IoT Core → **MQTT test client**, subscribe to
`edge/dht22/telemetry` to see the JSON messages.

## GitHub Actions deployment

The Terraform workflow uses a Tailscale OAuth client to connect to the edge
device. Configure an OAuth client with the `auth_keys` scope and permission to
use `tag:github-actions`, then add these as GitHub Actions repository secrets:

- `TS_OAUTH_CLIENT_ID`
- `TS_OAUTH_SECRET`

The previous `TS_AUTHKEY` secret is no longer used by the workflow and can be
removed.

## Cleanup

```bash
cd terraform
terraform destroy
```
