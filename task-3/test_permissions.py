import json
import boto3
import os

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://host.docker.internal:4566')
s3 = boto3.client('s3', endpoint_url=endpoint_url)

def handler(event, context):
    bucket = 'processing-bucket'
    results = {}

    try:
        response = s3.get_object(Bucket=bucket, Key='input/file1.txt')
        results['read_input'] = 'SUCCESS'
    except Exception as e:
        results['read_input'] = f'FAILED: {str(e)}'

    try:
        s3.put_object(Bucket=bucket, Key='output/test-output.txt', Body=b'Test output')
        results['write_output'] = 'SUCCESS'
    except Exception as e:
        results['write_output'] = f'FAILED: {str(e)}'

    try:
        response = s3.get_object(Bucket=bucket, Key='secret/confidential.txt')
        results['read_secret'] = 'SUCCESS (should be denied!)'
    except Exception as e:
        results['read_secret'] = f'DENIED (expected): {str(e)}'

    return {
        'statusCode': 200,
        'body': json.dumps(results, indent=2)
    }
