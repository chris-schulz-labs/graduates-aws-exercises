import json
import boto3
import os
from datetime import datetime

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://host.docker.internal:4566')
s3 = boto3.client('s3', endpoint_url=endpoint_url)

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    print(f"Using endpoint: {endpoint_url}")

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        event_name = record['eventName']

        print(f"Processing {event_name} for {bucket}/{key}")

        if not key.startswith('input/'):
            print(f"Ignoring object not in input/: {key}")
            continue

        try:
            response = s3.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')

            processed_content = {
                'original_file': key,
                'processed_at': datetime.utcnow().isoformat(),
                'original_content': content,
                'word_count': len(content.split()),
                'character_count': len(content),
                'uppercase_content': content.upper()
            }

            output_key = key.replace('input/', 'output/')
            output_key = output_key.replace('.txt', '-processed.json')

            s3.put_object(
                Bucket=bucket,
                Key=output_key,
                Body=json.dumps(processed_content, indent=2),
                ContentType='application/json'
            )

            print(f"Successfully processed {key} -> {output_key}")

        except Exception as e:
            print(f"Error processing {key}: {str(e)}")
            raise

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }
