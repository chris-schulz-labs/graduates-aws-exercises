#!/bin/bash

set -e

PROFILE="localstack"
BUCKET_NAME="processing-bucket"
ROLE_NAME="lambda-s3-processor"
POLICY_NAME="S3ScopedAccessPolicy"
FUNCTION_NAME="permission-tester"

echo "Cleaning up IAM and Lambda resources..."

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
rm -f input.txt output.txt secret.txt test-function.zip response.json

echo "✓ Cleanup complete"
