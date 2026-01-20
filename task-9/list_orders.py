import json
import os
import boto3

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)
orders_table = dynamodb.Table('Orders')

def lambda_handler(event, context):
    try:
        response = orders_table.scan()

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'count': response['Count'],
                'orders': response['Items']
            }, default=str)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
