import configparser
import json
import os
import time
from pathlib import Path

import board
import adafruit_dht
from awscrt import mqtt
from awsiot import mqtt_connection_builder
#
# ---------------------------------------------------------------------------
# AWS IoT Core connection settings.
# Provide these via environment variables (see the Terraform outputs and the
# generated terraform/certs/ directory).
# ---------------------------------------------------------------------------
IOT_ENDPOINT = "a2ees2p88l8a5j-ats.iot.eu-central-1.amazonaws.com"  # e.g. xxxxx-ats.iot.eu-central-1.amazonaws.com
CLIENT_ID = "edge-dht22-sensor"
TOPIC = "edge/dht22/telemetry"

CERT_PATH = "/app/certs/device.pem.crt"
PRIVATE_KEY_PATH = "/app/certs/private.pem.key"
ROOT_CA_PATH = "/app/certs/AmazonRootCA1.pem"

PUBLISH_INTERVAL_S = float(os.environ.get("IOT_PUBLISH_INTERVAL_S", "300"))

def build_connection():
    """Create an mTLS MQTT connection to AWS IoT Core."""
    return mqtt_connection_builder.mtls_from_path(
        endpoint=IOT_ENDPOINT,
        cert_filepath=CERT_PATH,
        pri_key_filepath=PRIVATE_KEY_PATH,
        ca_filepath=ROOT_CA_PATH,
        client_id=CLIENT_ID,
        clean_session=False,
        keep_alive_secs=30,
    )


def main():
    # Initialize the DHT22 sensor on GPIO 4 (Physical Pin 7, BCM GPIO 4).
    dht_sensor = adafruit_dht.DHT22(board.D4)

    mqtt_connection = build_connection()
    print(f"Connecting to {IOT_ENDPOINT} as '{CLIENT_ID}'...")
    mqtt_connection.connect().result()
    print(f"Connected. Publishing to '{TOPIC}'. Press Ctrl+C to exit.\n")

    try:
        while True:

            PUBLISH_INTERVAL_S = float(os.environ.get("IOT_PUBLISH_INTERVAL_S", "300"))
            
            try:
                # Retrieve temperature (in Celsius) and relative humidity (%)
                temperature_c = dht_sensor.temperature
                humidity = dht_sensor.humidity

                if temperature_c is not None and humidity is not None:
                    temperature_f = temperature_c * (9 / 5) + 32
                    payload = {
                        "timestamp": int(time.time()),
                        "device_id": CLIENT_ID,
                        "temperature_c": round(temperature_c, 1),
                        "temperature_f": round(temperature_f, 1),
                        "humidity": round(humidity, 1),
                    }

                    mqtt_connection.publish(
                        topic=TOPIC,
                        payload=json.dumps(payload),
                        qos=mqtt.QoS.AT_LEAST_ONCE,
                    )
                    print(f"[{time.strftime('%H:%M:%S')}] Published: {payload}")

            except RuntimeError as error:
                # DHT22 timing quirks are common on Linux; keep the loop running.
                print(f"[{time.strftime('%H:%M:%S')}] Sensor read failed: {error.args[0]}")

            time.sleep(PUBLISH_INTERVAL_S)

    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        dht_sensor.exit()
        mqtt_connection.disconnect().result()
        print("Disconnected.")


if __name__ == "__main__":
    main()