#!/bin/bash

set -e

PROFILE="localstack"
BUCKET_NAME="task-results"
API_NAME="task-api"

echo "Cleaning up SQS and async processing resources..."

API_ID=$(aws --profile $PROFILE apigateway get-rest-apis \
  --query "items[?name=='$API_NAME'].id" --output text 2>/dev/null || echo "")

if [ -n "$API_ID" ]; then
  echo "Deleting REST API..."
  aws --profile $PROFILE apigateway delete-rest-api --rest-api-id $API_ID 2>/dev/null || true
fi

echo "Deleting event source mappings..."
MAPPING_UUIDS=$(aws --profile $PROFILE lambda list-event-source-mappings \
  --function-name task-processor --query 'EventSourceMappings[].UUID' --output text 2>/dev/null || echo "")

for UUID in $MAPPING_UUIDS; do
  aws --profile $PROFILE lambda delete-event-source-mapping --uuid $UUID 2>/dev/null || true
done

echo "Deleting Lambda functions..."
aws --profile $PROFILE lambda delete-function --function-name task-processor 2>/dev/null || true
aws --profile $PROFILE lambda delete-function --function-name api-enqueue 2>/dev/null || true

echo "Detaching policies and deleting roles..."
aws --profile $PROFILE iam detach-role-policy \
  --role-name lambda-sqs-processor \
  --policy-arn arn:aws:iam::000000000000:policy/SQSProcessorPolicy 2>/dev/null || true

aws --profile $PROFILE iam detach-role-policy \
  --role-name lambda-api-enqueue \
  --policy-arn arn:aws:iam::000000000000:policy/ApiEnqueuePolicy 2>/dev/null || true

aws --profile $PROFILE iam delete-policy \
  --policy-arn arn:aws:iam::000000000000:policy/SQSProcessorPolicy 2>/dev/null || true

aws --profile $PROFILE iam delete-policy \
  --policy-arn arn:aws:iam::000000000000:policy/ApiEnqueuePolicy 2>/dev/null || true

aws --profile $PROFILE iam delete-role --role-name lambda-sqs-processor 2>/dev/null || true
aws --profile $PROFILE iam delete-role --role-name lambda-api-enqueue 2>/dev/null || true

echo "Deleting SQS queues..."
QUEUE_URL=$(aws --profile $PROFILE sqs get-queue-url \
  --queue-name task-queue --query 'QueueUrl' --output text 2>/dev/null || echo "")
if [ -n "$QUEUE_URL" ]; then
  aws --profile $PROFILE sqs delete-queue --queue-url $QUEUE_URL 2>/dev/null || true
fi

DLQ_URL=$(aws --profile $PROFILE sqs get-queue-url \
  --queue-name task-dlq --query 'QueueUrl' --output text 2>/dev/null || echo "")
if [ -n "$DLQ_URL" ]; then
  aws --profile $PROFILE sqs delete-queue --queue-url $DLQ_URL 2>/dev/null || true
fi

echo "Emptying and deleting S3 bucket..."
aws --profile $PROFILE s3 rm s3://$BUCKET_NAME --recursive 2>/dev/null || true
aws --profile $PROFILE s3 rb s3://$BUCKET_NAME 2>/dev/null || true

echo "Removing local files..."
rm -f function.zip api-function.zip

echo "✓ Cleanup complete"
