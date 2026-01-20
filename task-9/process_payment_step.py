import json
import random

def lambda_handler(event, context):
    total_price = event['validation']['totalPrice']

    success = random.random() < 0.95

    if not success:
        raise Exception('Payment gateway error')

    return {
        'paymentStatus': 'completed',
        'transactionId': f'TXN-{random.randint(100000, 999999)}',
        'amount': total_price
    }
