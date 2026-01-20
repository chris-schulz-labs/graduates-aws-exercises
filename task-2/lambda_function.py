import json
import os

def handler(event, context):
    name = event.get('name', 'World')
    operation = event.get('operation', 'greet')
    greeting = os.environ.get('GREETING', 'Hello')

    if operation == 'greet':
        message = f"{greeting}, {name}!"
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': message,
                'operation': operation
            })
        }
    elif operation == 'farewell':
        message = f"Goodbye, {name}!"
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': message,
                'operation': operation
            })
        }
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': f"Unknown operation: {operation}"
            })
        }
