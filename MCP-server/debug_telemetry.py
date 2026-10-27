import boto3
from boto3.dynamodb.conditions import Key
import numpy as np
import traceback

def run_diagnosis():
    print("Connecting to DynamoDB...")
    dynamodb = boto3.resource('dynamodb', region_name='eu-central-1')
    table = dynamodb.Table('edge-dht22-telemetry-DB') # Update table name if different

    try:
        print("Executing test query for device 'edge-dht22-sensor'...")
        response = table.query(
            KeyConditionExpression=Key('device_id').eq('edge-dht22-sensor'),
            ScanIndexForward=False,
            Limit=50
        )
        items = response.get('Items', [])
        print(f"Success! Fetched {len(items)} items.")
        
        if not items:
            print("WARNING: Table query returned 0 items. Check your device_id partition key.")
            return

        print("Sample raw item:", items[0])

        temps = []
        humidities = []
        for i in items:
            if 'temperature_c' in i and 'humidity' in i:
                print(i)
                temps.append(float(i['temperature_c']))
                humidities.append(float(i['humidity']))

        print(f"Extracted {len(temps)} valid temperature-humidity pairs.")

        if len(temps) < 2:
            print("ERROR: Fewer than 2 valid data points. Cannot run numpy correlation.")
            return

        correlation_matrix = np.corrcoef(temps, humidities)
        print("Correlation calculation successful!")
        print("Result matrix:", correlation_matrix)

    except Exception as e:
        print("\n--- CAUGHT EXCEPTION ---")
        traceback.print_exc()

if __name__ == "__main__":
    run_diagnosis()