import json

def lambda_handler(event, context):
    """Validate order data."""
    order_id = event.get('orderId')
    amount = event.get('amount', 0)
    customer_id = event.get('customerId')

    if not order_id or not customer_id:
        return {
            'statusCode': 400,
            'valid': False,
            'error': 'Missing required fields'
        }

    if amount <= 0:
        return {
            'statusCode': 400,
            'valid': False,
            'error': 'Invalid amount'
        }

    return {
        'statusCode': 200,
        'valid': True,
        'orderId': order_id,
        'amount': amount,
        'customerId': customer_id
    }
