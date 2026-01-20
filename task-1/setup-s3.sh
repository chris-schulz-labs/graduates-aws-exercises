#!/bin/bash

set -e

BUCKET_NAME="training-bucket-demo"
PROFILE="localstack"

echo "=== Exercise 1: S3 Fundamentals Solution ==="
echo ""

echo "Step 1: Creating S3 bucket..."
aws --profile $PROFILE s3 mb s3://$BUCKET_NAME
echo "✓ Bucket created"
echo ""

echo "Step 2: Creating test files..."
echo "This is a public file" > public-file.txt
echo "This is a private file" > private-file.txt
echo "This is another private file" > private-file-2.txt
echo "✓ Test files created"
echo ""

echo "Step 3: Uploading objects to S3..."
aws --profile $PROFILE s3 cp public-file.txt s3://$BUCKET_NAME/public/public-file.txt
aws --profile $PROFILE s3 cp private-file.txt s3://$BUCKET_NAME/private/private-file.txt
aws --profile $PROFILE s3 cp private-file-2.txt s3://$BUCKET_NAME/private/private-file-2.txt
echo "✓ Objects uploaded"
echo ""

echo "Step 4: Listing objects..."
aws --profile $PROFILE s3 ls s3://$BUCKET_NAME/ --recursive
echo ""

echo "Step 5: Downloading an object..."
aws --profile $PROFILE s3 cp s3://$BUCKET_NAME/public/public-file.txt downloaded-file.txt
echo "Content: $(cat downloaded-file.txt)"
echo "✓ Object downloaded and verified"
echo ""

echo "Step 6: Enabling versioning..."
aws --profile $PROFILE s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled
echo "✓ Versioning enabled"
echo ""

echo "Step 7: Verifying versioning status..."
aws --profile $PROFILE s3api get-bucket-versioning --bucket $BUCKET_NAME
echo ""

echo "Step 8: Testing versioning with updated file..."
echo "This is an updated public file - version 2" > public-file.txt
aws --profile $PROFILE s3 cp public-file.txt s3://$BUCKET_NAME/public/public-file.txt
echo "✓ Updated file uploaded"
echo ""

echo "Step 9: Listing object versions..."
aws --profile $PROFILE s3api list-object-versions \
  --bucket $BUCKET_NAME \
  --prefix public/public-file.txt
echo ""

echo "Step 10: Creating bucket policy..."
cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForPublicPrefix",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/public/*"
    }
  ]
}
EOF
echo "✓ Policy file created"
echo ""

echo "Step 11: Applying bucket policy..."
aws --profile $PROFILE s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file://bucket-policy.json
echo "✓ Policy applied"
echo ""

echo "Step 12: Verifying bucket policy..."
aws --profile $PROFILE s3api get-bucket-policy --bucket $BUCKET_NAME
echo ""

echo "=== All steps completed successfully! ==="
echo ""
echo "Summary:"
echo "- Bucket: $BUCKET_NAME"
echo "- Objects: 3 files in public/ and private/ prefixes"
echo "- Versioning: Enabled"
echo "- Policy: Public read access to public/* prefix"
