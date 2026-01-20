import json
import random

def lambda_handler(event, context):
    """Check inventory availability (simulated)."""
    order_id = event.get('orderId')

    available = random.random() < 0.8

    return {
        'orderId': order_id,
        'amount': event.get('amount'),
        'customerId': event.get('customerId'),
        'inventoryAvailable': available,
        'stockLevel': random.randint(0, 100) if available else 0
    }
