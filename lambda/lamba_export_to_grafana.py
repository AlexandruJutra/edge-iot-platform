import json
import os
from decimal import Decimal
import boto3
from botocore.exceptions import ClientError

# Helper to handle DynamoDB Decimal types in JSON serialization
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

# Initialize the DynamoDB resource outside the handler for connection reuse
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = 'edge-dht22-telemetry-DB'

def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    try:
        
        response = table.scan()
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(response['Items'], cls=DecimalEncoder),
        }
            
    except ClientError as e:
        print(f"DynamoDB error: {e.response['Error']['Message']}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': e.response['Error']['Message']})
        }