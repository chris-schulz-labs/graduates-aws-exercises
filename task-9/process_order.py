import json
import os
import boto3

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
stepfunctions = boto3.client('stepfunctions', endpoint_url=endpoint_url)

STATE_MACHINE_ARN = 'arn:aws:states:us-east-1:000000000000:stateMachine:order-processing-workflow'

def lambda_handler(event, context):
    for record in event['Records']:
        order = json.loads(record['body'])

        execution_name = f"order-{order['orderId']}"

        stepfunctions.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            name=execution_name,
            input=json.dumps(order)
        )

    return {
        'statusCode': 200,
        'body': json.dumps({'message': f'Processed {len(event["Records"])} orders'})
    }
