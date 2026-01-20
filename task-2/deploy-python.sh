#!/bin/bash

set -e

PROFILE="localstack"
FUNCTION_NAME="hello-processor"

echo "=== Exercise 2: Lambda Basics Solution (Python) ==="
echo ""

echo "Step 1: Packaging Lambda function..."
zip function.zip lambda_function.py
echo "✓ Function packaged"
echo ""

echo "Step 2: Creating IAM role for Lambda..."
aws --profile $PROFILE iam create-role \
  --role-name lambda-basic-execution \
  --assume-role-policy-document file://trust-policy.json 2>/dev/null || echo "Role already exists"
echo "✓ IAM role created"
echo ""

echo "Step 3: Attaching execution policy..."
aws --profile $PROFILE iam attach-role-policy \
  --role-name lambda-basic-execution \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || echo "Policy already attached"
echo "✓ Policy attached"
echo ""

echo "Step 4: Creating Lambda function..."
aws --profile $PROFILE lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-basic-execution \
  --handler lambda_function.handler \
  --zip-file fileb://function.zip \
  --environment Variables={GREETING=Hello}
echo "✓ Function created"
echo ""

echo "Step 5: Testing with greet operation..."
aws --profile $PROFILE lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload '{"name": "Alice", "operation": "greet"}' \
  response.json
echo "Response: $(cat response.json)"
echo ""

echo "Step 6: Testing with farewell operation..."
aws --profile $PROFILE lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload '{"name": "Bob", "operation": "farewell"}' \
  response.json
echo "Response: $(cat response.json)"
echo ""

echo "Step 7: Testing with invalid operation..."
aws --profile $PROFILE lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload '{"name": "Charlie", "operation": "invalid"}' \
  response.json
echo "Response: $(cat response.json)"
echo ""

echo "Step 8: Updating environment variable..."
aws --profile $PROFILE lambda update-function-configuration \
  --function-name $FUNCTION_NAME \
  --environment Variables={GREETING=Greetings}
echo "✓ Environment variable updated"
echo ""

echo "Waiting for update to complete..."
sleep 2
echo ""

echo "Step 9: Testing with updated environment variable..."
aws --profile $PROFILE lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload '{"name": "Diana", "operation": "greet"}' \
  response.json
echo "Response: $(cat response.json)"
echo ""

echo "=== All steps completed successfully! ==="
echo ""
echo "Function details:"
aws --profile $PROFILE lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.[FunctionName,Runtime,Handler,Environment]'
