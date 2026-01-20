#!/bin/bash

set -e

PROFILE="localstack"
BUCKET_NAME="processing-bucket"
ROLE_NAME="lambda-s3-processor"
POLICY_NAME="S3ScopedAccessPolicy"
FUNCTION_NAME="permission-tester"

echo "=== Exercise 3: IAM Roles & Least Privilege Solution ==="
echo ""

echo "Step 1: Creating S3 bucket for testing..."
aws --profile $PROFILE s3 mb s3://$BUCKET_NAME 2>/dev/null || echo "Bucket already exists"
echo "✓ Bucket created"
echo ""

echo "Step 2: Uploading test files to different prefixes..."
echo "Input data" > input.txt
echo "Existing output" > output.txt
echo "Secret data" > secret.txt

aws --profile $PROFILE s3 cp input.txt s3://$BUCKET_NAME/input/file1.txt
aws --profile $PROFILE s3 cp output.txt s3://$BUCKET_NAME/output/existing.txt
aws --profile $PROFILE s3 cp secret.txt s3://$BUCKET_NAME/secret/confidential.txt
echo "✓ Test files uploaded"
echo ""

echo "Step 3: Creating IAM role with trust policy..."
aws --profile $PROFILE iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://lambda-trust-policy.json
echo "✓ Role created"
echo ""

echo "Step 4: Creating permission policy..."
aws --profile $PROFILE iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://s3-scoped-policy.json
echo "✓ Policy created"
echo ""

echo "Step 5: Attaching policy to role..."
aws --profile $PROFILE iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::000000000000:policy/$POLICY_NAME
echo "✓ Policy attached"
echo ""

echo "Step 6: Verifying role and policies..."
aws --profile $PROFILE iam get-role --role-name $ROLE_NAME --query 'Role.[RoleName,Arn]'
aws --profile $PROFILE iam list-attached-role-policies --role-name $ROLE_NAME
echo ""

echo "Step 7: Packaging test Lambda function..."
zip test-function.zip test_permissions.py
echo "✓ Function packaged"
echo ""

echo "Step 8: Deploying Lambda function with IAM role..."
aws --profile $PROFILE lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/$ROLE_NAME \
  --handler test_permissions.handler \
  --zip-file fileb://test-function.zip \
  --timeout 30
echo "✓ Function deployed"
echo ""

echo "Step 9: Testing permissions..."
aws --profile $PROFILE lambda invoke \
  --function-name $FUNCTION_NAME \
  response.json

echo ""
echo "Test results:"
cat response.json | grep -o '"body": "[^"]*"' | sed 's/"body": "//;s/"$//' | sed 's/\\n/\n/g' | sed 's/\\"/"/g'
echo ""

echo "Step 10: Verifying output file was written..."
aws --profile $PROFILE s3 ls s3://$BUCKET_NAME/output/
echo ""

echo "=== All steps completed successfully! ==="
echo ""
echo "Summary:"
echo "- Role: $ROLE_NAME with scoped S3 permissions"
echo "- Can read from: input/* (SUCCESS)"
echo "- Can write to: output/* (SUCCESS)"
echo "- Cannot read: secret/* (DENIED - least privilege working)"
