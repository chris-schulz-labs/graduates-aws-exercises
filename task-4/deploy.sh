#!/bin/bash

set -e

PROFILE="localstack"
BUCKET_NAME="event-processing-bucket"
ROLE_NAME="lambda-s3-event-processor"
POLICY_NAME="S3EventProcessingPolicy"
FUNCTION_NAME="s3-event-processor"

echo "=== Exercise 4: Lambda + S3 Event Processing Solution ==="
echo ""

echo "Step 1: Creating S3 bucket..."
aws --profile $PROFILE s3 mb s3://$BUCKET_NAME
echo "✓ Bucket created"
echo ""

echo "Step 2: Creating IAM role..."
aws --profile $PROFILE iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://lambda-trust-policy.json
echo "✓ Role created"
echo ""

echo "Step 3: Creating and attaching permission policy..."
aws --profile $PROFILE iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://s3-event-policy.json

aws --profile $PROFILE iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::000000000000:policy/$POLICY_NAME
echo "✓ Policy attached"
echo ""

echo "Step 4: Packaging Lambda function..."
zip function.zip s3_processor.py
echo "✓ Function packaged"
echo ""

echo "Step 5: Deploying Lambda function..."
aws --profile $PROFILE lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/$ROLE_NAME \
  --handler s3_processor.handler \
  --zip-file fileb://function.zip \
  --timeout 60
echo "✓ Function deployed"
echo ""

echo "Step 6: Granting S3 permission to invoke Lambda..."
aws --profile $PROFILE lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id s3-invoke-permission \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::$BUCKET_NAME
echo "✓ Permission granted"
echo ""

echo "Step 7: Configuring S3 event notification..."
aws --profile $PROFILE s3api put-bucket-notification-configuration \
  --bucket $BUCKET_NAME \
  --notification-configuration file://notification-config.json
echo "✓ Event notification configured"
echo ""

echo "Step 8: Verifying configuration..."
aws --profile $PROFILE s3api get-bucket-notification-configuration \
  --bucket $BUCKET_NAME
echo ""

echo "Step 9: Testing with sample file..."
echo "Hello from S3 event processing" > test-input.txt
aws --profile $PROFILE s3 cp test-input.txt s3://$BUCKET_NAME/input/test-input.txt
echo "✓ Test file uploaded"
echo ""

echo "Waiting for processing..."
sleep 3
echo ""

echo "Step 10: Checking output..."
aws --profile $PROFILE s3 ls s3://$BUCKET_NAME/output/
echo ""

echo "Step 11: Downloading processed file..."
aws --profile $PROFILE s3 cp \
  s3://$BUCKET_NAME/output/test-input-processed.json \
  result.json
echo ""
echo "Processed content:"
cat result.json
echo ""

echo "Step 12: Testing with multiple files..."
echo "First file content" > file1.txt
echo "Second file with more content" > file2.txt
echo "Third file here" > file3.txt

aws --profile $PROFILE s3 cp file1.txt s3://$BUCKET_NAME/input/file1.txt
aws --profile $PROFILE s3 cp file2.txt s3://$BUCKET_NAME/input/file2.txt
aws --profile $PROFILE s3 cp file3.txt s3://$BUCKET_NAME/input/file3.txt
echo "✓ Multiple files uploaded"
echo ""

echo "Waiting for processing..."
sleep 3
echo ""

echo "Final output listing:"
aws --profile $PROFILE s3 ls s3://$BUCKET_NAME/output/
echo ""

echo "=== All steps completed successfully! ==="
echo ""
echo "Summary:"
echo "- S3 bucket: $BUCKET_NAME"
echo "- Lambda function: $FUNCTION_NAME"
echo "- Event trigger: ObjectCreated on input/ prefix"
echo "- Processing: Automatic on file upload"
