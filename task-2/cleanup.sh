#!/bin/bash

set -e

PROFILE="localstack"
FUNCTION_NAME="hello-processor"

echo "Cleaning up Lambda resources..."

echo "Deleting Lambda function..."
aws --profile $PROFILElambda delete-function --function-name $FUNCTION_NAME 2>/dev/null || true

echo "Detaching policy from role..."
aws --profile $PROFILEiam detach-role-policy \
  --role-name lambda-basic-execution \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

echo "Deleting IAM role..."
aws --profile $PROFILEiam delete-role --role-name lambda-basic-execution 2>/dev/null || true

echo "Removing local files..."
rm -f function.zip response.json

echo "✓ Cleanup complete"
