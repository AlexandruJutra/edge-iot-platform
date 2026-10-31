from mcp.server.mcpserver import MCPServer
import boto3
from boto3.dynamodb.conditions import Key
import numpy as np

mcp = MCPServer("IoT-Telemetry")

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name='eu-central-1')
table = dynamodb.Table('edge-dht22-telemetry-DB')

@mcp.tool()
def get_latest_telemetry() -> dict:
    """Fetch the latest temperature and humidity sensor reading."""
    # Assuming device_id is partition key and timestamp is sort key
    response = table.query(
        KeyConditionExpression=Key('device_id').eq('edge-dht22-sensor'),
        ScanIndexForward=False, # Descending order
        Limit=1
    )
    items = response.get('Items', [])
    if not items:
        return {"error": "No telemetry data found."}
    return items[0]

@mcp.tool()
def get_telemetry_range(start_iso: str, end_iso: str) -> list:
    """Fetch sensor readings between a specific start and end ISO timestamp."""
    response = table.query(
        KeyConditionExpression=Key('device_id').eq('edge-dht22-sensor') & 
                               Key('timestamp').between(start_iso, end_iso)
    )
    return response.get('Items', [])

@mcp.tool()
def analyze_environmental_correlation(start_iso: str, end_iso: str) -> dict:
    """Calculate statistical correlation between temperature and humidity over a given time range. INFO: when the temprature is rising quick, it is ussualy because the fire in the Wood-fired central heating system has been lit."""
    items = get_telemetry_range(start_iso, end_iso)
    if len(items) < 2:
        return {"error": "Insufficient data points for correlation analysis."}
    
    temps = [float(i['temperature_c']) for i in items if 'temperature_c' in i]
    humidities = [float(i['humidity']) for i in items if 'humidity' in i]
    
    correlation_matrix = np.corrcoef(temps, humidities)
    r_value = correlation_matrix[0, 1]
    
    return {
        "data_points": len(items),
        "pearson_r": round(float(r_value), 4),
        "interpretation": "Strong inverse relationship" if r_value < -0.7 else "Moderate/Weak relationship"
    }

if __name__ == "__main__":
    # Run using Streamable HTTP transport on port 8000
    mcp.run(transport="sse", host="0.0.0.0", port=8000)