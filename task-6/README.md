# Exercise 6: SQS + Async Processing

**Duration**: 25-30 minutes
**Prerequisites**: Completed Exercises 1-5, understand Lambda, API Gateway, and S3, AWS CLI configured with localstack profile

**Note**: All commands below assume you've set `export AWS_PROFILE=localstack`. Alternatively, add `--profile localstack` to each command.

## Learning Objectives

By completing this exercise, you will:
- Create SQS queues for asynchronous message processing
- Configure dead-letter queues (DLQ) for failed messages
- Integrate API Gateway with SQS for asynchronous task submission
- Configure Lambda to process SQS messages automatically
- Implement retry logic and error handling
- Understand message visibility and processing guarantees
- Store processing results in S3

## Background

SQS (Simple Queue Service) enables asynchronous, decoupled communication between components. Instead of processing requests synchronously, tasks are queued and processed later.

**Key Concepts**:
- **Queue**: FIFO or Standard queue holding messages
- **Message**: Task data sent to queue
- **Visibility Timeout**: Time a message is hidden from other consumers after being received
- **Dead-Letter Queue (DLQ)**: Queue for messages that fail processing repeatedly
- **MaxReceiveCount**: Number of processing attempts before moving to DLQ
- **Event Source Mapping**: Connection between SQS and Lambda
- **Batch Processing**: Lambda processes multiple messages in one invocation

**Benefits**:
- Decouple API from long-running tasks
- Handle traffic spikes (queue absorbs load)
- Retry failed operations automatically
- Scale processing independently from API

**Use Cases**:
- Image/video processing
- Email sending
- Data imports
- Report generation
- Batch operations

## Tasks

### Task 6.1: Create SQS Queues

**Create dead-letter queue** (for failed messages):
```bash
aws sqs create-queue \
  --queue-name task-dlq
```

Get DLQ ARN:
```bash
DLQ_URL=$(aws sqs get-queue-url \
  --queue-name task-dlq --query 'QueueUrl' --output text)

DLQ_ARN=$(aws sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text)

echo "DLQ ARN: $DLQ_ARN"
```

**Create main queue with DLQ**:
```bash
aws sqs create-queue \
  --queue-name task-queue \
  --attributes "{
    \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\",
    \"VisibilityTimeout\": \"60\"
  }"
```

Get queue URL:
```bash
QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name task-queue --query 'QueueUrl' --output text)

echo "Queue URL: $QUEUE_URL"
```

Verify configuration:
```bash
aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names All
```

### Task 6.2: Create S3 Bucket for Results

```bash
aws s3 mb s3://task-results
```

### Task 6.3: Create IAM Role for Processing Lambda

**Trust policy** (`lambda-trust-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Permission policy** (`processor-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:us-east-1:000000000000:task-queue"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::task-results/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

**Create role**:
```bash
aws iam create-role \
  --role-name lambda-sqs-processor \
  --assume-role-policy-document file://lambda-trust-policy.json

aws iam create-policy \
  --policy-name SQSProcessorPolicy \
  --policy-document file://processor-policy.json

aws iam attach-role-policy \
  --role-name lambda-sqs-processor \
  --policy-arn arn:aws:iam::000000000000:policy/SQSProcessorPolicy
```

### Task 6.4: Create Task Processor Lambda Function

**Python version** (`task_processor.py`):
```python
import json
import boto3
import os
import time
from datetime import datetime

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
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
```

**Package and deploy**:
```bash
zip function.zip task_processor.py

aws lambda create-function \
  --function-name task-processor \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-sqs-processor \
  --handler task_processor.handler \
  --zip-file fileb://function.zip \
  --timeout 120

aws lambda update-function-configuration \
  --function-name task-processor \
  --environment "Variables={AWS_ENDPOINT_URL=http://aws-training-localstack:4566}"
```

**Note**: The environment variable `AWS_ENDPOINT_URL` is set to the LocalStack container hostname. This is required because Lambda functions run in isolated Docker containers and cannot reach `localhost:4566`.

### Task 6.5: Configure SQS Event Source Mapping

Connect SQS queue to Lambda:

```bash
QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text)

aws lambda create-event-source-mapping \
  --function-name task-processor \
  --event-source-arn $QUEUE_ARN \
  --batch-size 5 \
  --maximum-batching-window-in-seconds 10
```

Verify mapping:
```bash
aws lambda list-event-source-mappings \
  --function-name task-processor
```

### Task 6.6: Create API Lambda to Enqueue Tasks

**Python version** (`api_enqueue.py`):
```python
import json
import boto3
import os
import uuid

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
sqs = boto3.client('sqs', endpoint_url=endpoint_url)
QUEUE_URL = os.environ.get('QUEUE_URL', 'http://localhost:4566/000000000000/task-queue')

def handler(event, context):
    print(f"Received request: {json.dumps(event)}")

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
```

**Deploy API Lambda**:
```bash
zip api-function.zip api_enqueue.py

aws iam create-role \
  --role-name lambda-api-enqueue \
  --assume-role-policy-document file://lambda-trust-policy.json

cat > api-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "arn:aws:sqs:us-east-1:000000000000:task-queue"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ApiEnqueuePolicy \
  --policy-document file://api-policy.json

aws iam attach-role-policy \
  --role-name lambda-api-enqueue \
  --policy-arn arn:aws:iam::000000000000:policy/ApiEnqueuePolicy

aws lambda create-function \
  --function-name api-enqueue \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-api-enqueue \
  --handler api_enqueue.handler \
  --zip-file fileb://api-function.zip \
  --timeout 30

QUEUE_URL=$(aws sqs get-queue-url --queue-name task-queue --query 'QueueUrl' --output text)
aws lambda update-function-configuration \
  --function-name api-enqueue \
  --environment "Variables={AWS_ENDPOINT_URL=http://aws-training-localstack:4566,QUEUE_URL=$QUEUE_URL}"
```

**Note**: Like the processor function, we set `AWS_ENDPOINT_URL` to the LocalStack container hostname for proper Docker networking.

### Task 6.7: Create API Gateway for Task Submission

```bash
aws apigateway create-rest-api \
  --name task-api \
  --description "Async Task Submission API"

API_ID=$(aws apigateway get-rest-apis \
  --query 'items[?name==`task-api`].id' --output text)

ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID --query 'items[0].id' --output text)

TASKS_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part tasks \
  --query 'id' --output text)

aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $TASKS_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE

LAMBDA_ARN="arn:aws:lambda:us-east-1:000000000000:function:api-enqueue"

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $TASKS_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev
```

### Task 6.8: Test the Async Processing Pipeline

**Submit compute task**:
```bash
curl -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "compute",
    "data": {
      "numbers": [10, 20, 30, 40, 50]
    }
  }'
```

**Submit transform task**:
```bash
curl -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "transform",
    "data": {
      "text": "Hello World from SQS Processing"
    }
  }'
```

**Submit failing task (for DLQ testing)**:
```bash
curl -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "fail",
    "data": {}
  }'
```

**Wait for processing**:
```bash
sleep 5
```

**Check results in S3**:
```bash
aws s3 ls s3://task-results/results/
```

**Download a result**:
```bash
aws s3 cp \
  s3://task-results/results/ . --recursive
cat *.json
```

**Check DLQ for failed messages**:
```bash
aws sqs receive-message \
  --queue-url $DLQ_URL \
  --max-number-of-messages 10
```

### Task 6.9: Monitor Queues

**Check queue metrics**:
```bash
aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible
```

**Check DLQ metrics**:
```bash
aws sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names ApproximateNumberOfMessages
```

## Success Criteria

- [ ] SQS queue created with DLQ configuration
- [ ] DLQ created for failed messages
- [ ] S3 bucket created for results
- [ ] Processor Lambda function deployed with SQS permissions
- [ ] Event source mapping connects SQS to Lambda
- [ ] API Lambda function deployed with SQS send permission
- [ ] API Gateway endpoint created for task submission
- [ ] POST to API returns 202 (Accepted) status
- [ ] Tasks automatically processed by Lambda from queue
- [ ] Processing results written to S3
- [ ] Failed tasks moved to DLQ after 3 retries
- [ ] Multiple tasks processed successfully

## Testing Your Work

```bash
for i in {1..5}; do
  curl -s -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/tasks" \
    -H "Content-Type: application/json" \
    -d "{\"task_type\": \"compute\", \"data\": {\"numbers\": [$(($i*10)), $(($i*20)), $(($i*30))]}}"
  echo ""
done

sleep 10

echo "Results in S3:"
aws s3 ls s3://task-results/results/

echo ""
echo "Queue status:"
aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages
```

## Common Pitfalls

1. **Visibility timeout too short**: If processing takes longer than visibility timeout, messages reappear in queue

2. **MaxReceiveCount**: Set appropriately based on expected failure rate and retry needs

3. **Batch size**: Lambda receives 1-10 messages per invocation. Adjust based on processing time.

4. **Error handling**: If Lambda throws exception, message becomes visible again for retry

5. **DLQ monitoring**: Failed messages in DLQ need manual inspection and reprocessing

6. **Message deletion**: Lambda automatically deletes messages on successful processing (with event source mapping)

## LocalStack-Specific Notes

- Queue URLs use localhost:4566 format
- Account ID is always 000000000000
- Message delivery is nearly instant (faster than real AWS)
- Event source mapping works similarly to real AWS
- DLQ behavior matches AWS standards
- **Lambda networking**: When Lambda functions run in Docker executor mode (default), they execute in isolated containers on the Docker network. They cannot access `localhost:4566` and must use the LocalStack container hostname (`aws-training-localstack:4566`) instead. This is why we use environment variables for endpoint URLs.

## Key Concepts Review

- **Asynchronous Processing**: Decouple request from execution
- **Message Queue**: Buffer between producers and consumers
- **Visibility Timeout**: Prevents concurrent processing of same message
- **Dead-Letter Queue**: Captures messages that fail repeatedly
- **MaxReceiveCount**: Retry limit before moving to DLQ
- **Event Source Mapping**: Lambda polls SQS for messages
- **Batch Processing**: Process multiple messages per Lambda invocation
- **At-Least-Once Delivery**: Messages may be delivered multiple times

## Extension Challenges

If you finish early:

1. Add FIFO queue for ordered processing
2. Implement message deduplication
3. Add SNS notifications for DLQ messages
4. Create monitoring dashboard for queue metrics
5. Add priority queues (separate queues for high/low priority)

## Wrap-Up

You've now completed all 6 exercises covering:
1. S3 object storage
2. Lambda serverless functions
3. IAM security and permissions
4. Event-driven S3+Lambda processing
5. REST APIs with API Gateway
6. Asynchronous processing with SQS

These services form the foundation of serverless architectures on AWS.
