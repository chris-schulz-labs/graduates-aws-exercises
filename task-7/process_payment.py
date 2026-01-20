import json
import random

def lambda_handler(event, context):
    """Process payment (simulated)."""
    order_id = event.get('orderId')
    amount = event.get('amount')

    success = random.random() < 0.9

    if not success:
        raise Exception('Payment processing failed')

    return {
        'orderId': order_id,
        'amount': amount,
        'customerId': event.get('customerId'),
        'paymentStatus': 'completed',
        'transactionId': f'txn-{order_id}-{random.randint(1000, 9999)}'
    }
