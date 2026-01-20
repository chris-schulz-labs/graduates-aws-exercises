import json
import boto3
import os

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localstack:4566')
sqs = boto3.client('sqs', endpoint_url=endpoint_url)

def handler(event, context):
    print(f"Received request: {json.dumps(event)}")

    QUEUE_URL = os.environ.get('QUEUE_URL', 'http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/task-queue')

    body = event.get('body')
    if not body:
        return response(400, {'error': 'Missing request body'})

    try:
        data = json.loads(body)
        task_type = data.get('task_type')
        task_data = data.get('data', {})

        if not task_type:
            return response(400, {'error': 'Missing task_type'})

        message = {
            'task_type': task_type,
            'data': task_data,
            'submitted_at': data.get('submitted_at')
        }

        result = sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message)
        )

        return response(202, {
            'message': 'Task queued successfully',
            'message_id': result['MessageId'],
            'task_type': task_type
        })

    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        return response(500, {'error': str(e)})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json'
        },
        'body': json.dumps(body)
    }
