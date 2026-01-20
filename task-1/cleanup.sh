#!/bin/bash

set -e

BUCKET_NAME="training-bucket-demo"
PROFILE="localstack"

echo "Cleaning up S3 resources..."

echo "Removing all object versions..."
aws --profile $PROFILEs3api delete-objects \
  --bucket $BUCKET_NAME \
  --delete "$(aws --profile $PROFILEs3api list-object-versions \
    --bucket $BUCKET_NAME \
    --output json \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true

echo "Removing delete markers..."
aws --profile $PROFILEs3api delete-objects \
  --bucket $BUCKET_NAME \
  --delete "$(aws --profile $PROFILEs3api list-object-versions \
    --bucket $BUCKET_NAME \
    --output json \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true

echo "Deleting bucket..."
aws --profile $PROFILEs3 rb s3://$BUCKET_NAME --force 2>/dev/null || true

echo "Removing local test files..."
rm -f public-file.txt private-file.txt private-file-2.txt downloaded-file.txt bucket-policy.json

echo "✓ Cleanup complete"
