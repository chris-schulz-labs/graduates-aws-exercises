#!/bin/bash

set -e

PROFILE="localstack"
BUCKET_NAME="api-data-store"
ROLE_NAME="lambda-api-role"
POLICY_NAME="ApiLambdaPolicy"
FUNCTION_NAME="api-handler"
API_NAME="items-api"

echo "Cleaning up API Gateway resources..."

API_ID=$(aws --profile $PROFILE apigateway get-rest-apis \
  --query "items[?name=='$API_NAME'].id" --output text 2>/dev/null || echo "")

if [ -n "$API_ID" ]; then
  echo "Deleting REST API..."
  aws --profile $PROFILE apigateway delete-rest-api --rest-api-id $API_ID 2>/dev/null || true
fi

echo "Deleting Lambda function..."
aws --profile $PROFILE lambda delete-function --function-name $FUNCTION_NAME 2>/dev/null || true

echo "Detaching policy from role..."
aws --profile $PROFILE iam detach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::000000000000:policy/$POLICY_NAME 2>/dev/null || true

echo "Deleting policy..."
aws --profile $PROFILE iam delete-policy \
  --policy-arn arn:aws:iam::000000000000:policy/$POLICY_NAME 2>/dev/null || true

echo "Deleting role..."
aws --profile $PROFILE iam delete-role --role-name $ROLE_NAME 2>/dev/null || true

echo "Emptying and deleting S3 bucket..."
aws --profile $PROFILE s3 rm s3://$BUCKET_NAME --recursive 2>/dev/null || true
aws --profile $PROFILE s3 rb s3://$BUCKET_NAME 2>/dev/null || true

echo "Removing local files..."
rm -f function.zip

echo "✓ Cleanup complete"
