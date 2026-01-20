import json
import os
import uuid
import boto3
from datetime import datetime

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)
sqs = boto3.client('sqs', endpoint_url=endpoint_url)

orders_table = dynamodb.Table('Orders')
QUEUE_URL = os.environ.get('QUEUE_URL', 'http://localhost:4566/000000000000/order-processing-queue')

def lambda_handler(event, context):
    try:
        body = json.loads(event.get('body', '{}'))

        order_id = str(uuid.uuid4())
        order = {
            'orderId': order_id,
            'customerId': body['customerId'],
            'productId': body['productId'],
            'quantity': int(body['quantity']),
            'status': 'pending',
            'createdAt': datetime.utcnow().isoformat()
        }

        orders_table.put_item(Item=order)

        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(order)
        )

        return {
            'statusCode': 202,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Order submitted for processing',
                'orderId': order_id
            })
        }
    except KeyError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Missing required field: {str(e)}'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
