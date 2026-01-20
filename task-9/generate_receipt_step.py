import json
import os
import boto3
from datetime import datetime

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
s3 = boto3.client('s3', endpoint_url=endpoint_url)

def lambda_handler(event, context):
    order_id = event['orderId']

    receipt = {
        'orderId': order_id,
        'customerId': event['customerId'],
        'product': event['validation']['product'],
        'quantity': event['quantity'],
        'totalPrice': event['validation']['totalPrice'],
        'transactionId': event['payment']['transactionId'],
        'timestamp': datetime.utcnow().isoformat()
    }

    receipt_content = json.dumps(receipt, indent=2)

    s3.put_object(
        Bucket='order-receipts',
        Key=f'receipts/{order_id}.json',
        Body=receipt_content,
        ContentType='application/json'
    )

    return {
        'receiptUrl': f's3://order-receipts/receipts/{order_id}.json'
    }
