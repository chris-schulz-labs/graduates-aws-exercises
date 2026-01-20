#!/bin/bash

set -e

PROFILE="localstack"
BUCKET_NAME="task-results"
API_NAME="task-api"

echo "=== Exercise 6: SQS + Async Processing Solution ==="
echo ""

echo "Step 1: Creating dead-letter queue..."
aws --profile $PROFILE sqs create-queue --queue-name task-dlq

DLQ_URL=$(aws --profile $PROFILE sqs get-queue-url \
  --queue-name task-dlq --query 'QueueUrl' --output text)

DLQ_ARN=$(aws --profile $PROFILE sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text)

echo "✓ DLQ created: $DLQ_ARN"
echo ""

echo "Step 2: Creating main queue with DLQ configuration..."
aws --profile $PROFILE sqs create-queue \
  --queue-name task-queue \
  --attributes "{
    \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\",
    \"VisibilityTimeout\": \"60\"
  }"

QUEUE_URL=$(aws --profile $PROFILE sqs get-queue-url \
  --queue-name task-queue --query 'QueueUrl' --output text)

QUEUE_ARN=$(aws --profile $PROFILE sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text)

echo "✓ Queue created: $QUEUE_ARN"
echo ""

echo "Step 3: Creating S3 bucket for results..."
aws --profile $PROFILE s3 mb s3://$BUCKET_NAME
echo "✓ Bucket created"
echo ""

echo "Step 4: Creating IAM role for processor Lambda..."
aws --profile $PROFILE iam create-role \
  --role-name lambda-sqs-processor \
  --assume-role-policy-document file://lambda-trust-policy.json

aws --profile $PROFILE iam create-policy \
  --policy-name SQSProcessorPolicy \
  --policy-document file://processor-policy.json

aws --profile $PROFILE iam attach-role-policy \
  --role-name lambda-sqs-processor \
  --policy-arn arn:aws:iam::000000000000:policy/SQSProcessorPolicy
echo "✓ Processor role created"
echo ""

echo "Step 5: Deploying task processor Lambda..."
zip function.zip task_processor.py

aws --profile $PROFILE lambda create-function \
  --function-name task-processor \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-sqs-processor \
  --handler task_processor.handler \
  --zip-file fileb://function.zip \
  --timeout 120

aws --profile $PROFILE lambda update-function-configuration \
  --function-name task-processor \
  --environment "Variables={AWS_ENDPOINT_URL=http://aws-training-localstack:4566}"
echo "✓ Processor function deployed with environment variables"
echo ""

echo "Step 6: Creating event source mapping..."
aws --profile $PROFILE lambda create-event-source-mapping \
  --function-name task-processor \
  --event-source-arn $QUEUE_ARN \
  --batch-size 5 \
  --maximum-batching-window-in-seconds 10
echo "✓ Event source mapping created"
echo ""

echo "Step 7: Creating IAM role for API Lambda..."
aws --profile $PROFILE iam create-role \
  --role-name lambda-api-enqueue \
  --assume-role-policy-document file://lambda-trust-policy.json

aws --profile $PROFILE iam create-policy \
  --policy-name ApiEnqueuePolicy \
  --policy-document file://api-policy.json

aws --profile $PROFILE iam attach-role-policy \
  --role-name lambda-api-enqueue \
  --policy-arn arn:aws:iam::000000000000:policy/ApiEnqueuePolicy
echo "✓ API role created"
echo ""

echo "Step 8: Deploying API Lambda..."
zip api-function.zip api_enqueue.py

aws --profile $PROFILE lambda create-function \
  --function-name api-enqueue \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-api-enqueue \
  --handler api_enqueue.handler \
  --zip-file fileb://api-function.zip \
  --timeout 30

aws --profile $PROFILE lambda update-function-configuration \
  --function-name api-enqueue \
  --environment "Variables={AWS_ENDPOINT_URL=http://aws-training-localstack:4566,QUEUE_URL=$QUEUE_URL}"
echo "✓ API function deployed with environment variables"
echo ""

echo "Step 9: Creating API Gateway..."
aws --profile $PROFILE apigateway create-rest-api \
  --name $API_NAME \
  --description "Async Task Submission API"

API_ID=$(aws --profile $PROFILE apigateway get-rest-apis \
  --query "items[?name=='$API_NAME'].id" --output text)

ROOT_ID=$(aws --profile $PROFILE apigateway get-resources \
  --rest-api-id $API_ID --query 'items[0].id' --output text)

TASKS_RESOURCE_ID=$(aws --profile $PROFILE apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part tasks \
  --query 'id' --output text)

aws --profile $PROFILE apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $TASKS_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE

LAMBDA_ARN="arn:aws:lambda:us-east-1:000000000000:function:api-enqueue"

aws --profile $PROFILE apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $TASKS_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

aws --profile $PROFILE apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev

echo "✓ API deployed"
echo ""

BASE_URL="http://localhost:4566/restapis/$API_ID/dev/_user_request_"
echo "API URL: $BASE_URL/tasks"
echo ""

echo "Step 10: Testing async processing pipeline..."
echo ""

echo "Test 1: Submitting compute task..."
curl -s -X POST "$BASE_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{"task_type": "compute", "data": {"numbers": [10, 20, 30, 40, 50]}}' | python3 -m json.tool
echo ""

echo "Test 2: Submitting transform task..."
curl -s -X POST "$BASE_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{"task_type": "transform", "data": {"text": "Hello World from SQS Processing"}}' | python3 -m json.tool
echo ""

echo "Test 3: Submitting multiple tasks..."
for i in {1..3}; do
  curl -s -X POST "$BASE_URL/tasks" \
    -H "Content-Type: application/json" \
    -d "{\"task_type\": \"compute\", \"data\": {\"numbers\": [$(($i*10)), $(($i*20)), $(($i*30))]}}" > /dev/null
done
echo "✓ Submitted 3 additional tasks"
echo ""

echo "Test 4: Submitting failing task (for DLQ)..."
curl -s -X POST "$BASE_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{"task_type": "fail", "data": {}}' > /dev/null
echo "✓ Failed task submitted"
echo ""

echo "Waiting for processing..."
sleep 10
echo ""

echo "Step 11: Checking results..."
echo "Results in S3:"
aws --profile $PROFILE s3 ls s3://$BUCKET_NAME/results/
echo ""

echo "Step 12: Downloading sample result..."
RESULT_FILE=$(aws --profile $PROFILE s3 ls s3://$BUCKET_NAME/results/ | head -1 | awk '{print $4}')
if [ -n "$RESULT_FILE" ]; then
  aws --profile $PROFILE s3 cp s3://$BUCKET_NAME/results/$RESULT_FILE - | python3 -m json.tool
  echo ""
fi

echo "Step 13: Checking queue status..."
aws --profile $PROFILE sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible
echo ""

echo "Step 14: Checking DLQ (should have failed message)..."
DLQ_MESSAGES=$(aws --profile $PROFILE sqs get-queue-attributes \
  --queue-url $DLQ_URL \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' --output text)
echo "Messages in DLQ: $DLQ_MESSAGES"
echo ""

echo "=== All steps completed successfully! ==="
echo ""
echo "Summary:"
echo "- Queue: task-queue with DLQ"
echo "- Processor: task-processor Lambda"
echo "- API: $BASE_URL/tasks"
echo "- Results: s3://$BUCKET_NAME/results/"
echo "- Failed messages in DLQ: $DLQ_MESSAGES"
