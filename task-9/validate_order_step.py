import json
import os
import boto3

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)
inventory_table = dynamodb.Table('Inventory')

def lambda_handler(event, context):
    product_id = event['productId']
    quantity = event['quantity']

    response = inventory_table.get_item(Key={'productId': product_id})

    if 'Item' not in response:
        return {
            'valid': False,
            'error': 'Product not found'
        }

    product = response['Item']
    stock = int(product['stock'])

    if stock < quantity:
        return {
            'valid': False,
            'error': f'Insufficient stock. Available: {stock}, Requested: {quantity}'
        }

    return {
        'valid': True,
        'product': product['name'],
        'unitPrice': float(product['price']),
        'totalPrice': float(product['price']) * quantity
    }
