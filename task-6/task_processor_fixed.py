import json
import boto3
import time
import os
from datetime import datetime

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localstack:4566')
s3 = boto3.client('s3', endpoint_url=endpoint_url)
BUCKET = 'task-results'

def handler(event, context):
    print(f"Processing {len(event['Records'])} messages")

    for record in event['Records']:
        message_id = record['messageId']
        body = json.loads(record['body'])

        print(f"Processing message {message_id}: {body}")

        try:
            task_type = body.get('task_type')
            task_data = body.get('data', {})

            if task_type == 'compute':
                result = process_compute_task(task_data)
            elif task_type == 'transform':
                result = process_transform_task(task_data)
            elif task_type == 'fail':
                raise Exception("Simulated failure for testing DLQ")
            else:
                raise ValueError(f"Unknown task type: {task_type}")

            result['message_id'] = message_id
            result['processed_at'] = datetime.utcnow().isoformat()

            result_key = f"results/{message_id}.json"
            s3.put_object(
                Bucket=BUCKET,
                Key=result_key,
                Body=json.dumps(result, indent=2),
                ContentType='application/json'
            )

            print(f"Successfully processed {message_id} -> {result_key}")

        except Exception as e:
            print(f"Error processing message {message_id}: {str(e)}")
            raise

    return {
        'statusCode': 200,
        'body': json.dumps(f'Processed {len(event["Records"])} messages')
    }

def process_compute_task(data):
    numbers = data.get('numbers', [])
    time.sleep(2)

    return {
        'task_type': 'compute',
        'input': numbers,
        'sum': sum(numbers),
        'average': sum(numbers) / len(numbers) if numbers else 0,
        'max': max(numbers) if numbers else None,
        'min': min(numbers) if numbers else None
    }

def process_transform_task(data):
    text = data.get('text', '')
    time.sleep(1)

    return {
        'task_type': 'transform',
        'input': text,
        'uppercase': text.upper(),
        'lowercase': text.lower(),
        'word_count': len(text.split()),
        'char_count': len(text)
    }
