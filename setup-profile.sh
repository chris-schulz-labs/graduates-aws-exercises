#!/bin/bash

set -e

echo "Setting up AWS profile for LocalStack..."

# Create AWS config directory if it doesn't exist
mkdir -p ~/.aws

CONFIG_FILE="$HOME/.aws/config"
CREDENTIALS_FILE="$HOME/.aws/credentials"

# Function to check if profile exists in a file
profile_exists() {
    local file=$1
    local profile=$2
    grep -q "^\[profile $profile\]" "$file" 2>/dev/null || grep -q "^\[$profile\]" "$file" 2>/dev/null
}

# Set up config file
if [ -f "$CONFIG_FILE" ] && profile_exists "$CONFIG_FILE" "localstack"; then
    echo "Profile 'localstack' already exists in $CONFIG_FILE, skipping..."
else
    echo "" >> "$CONFIG_FILE"
    echo "[profile localstack]" >> "$CONFIG_FILE"
    echo "region = us-east-1" >> "$CONFIG_FILE"
    echo "endpoint_url = http://localhost:4566" >> "$CONFIG_FILE"
    echo "Added profile 'localstack' to $CONFIG_FILE"
fi

# Set up credentials file
if [ -f "$CREDENTIALS_FILE" ] && profile_exists "$CREDENTIALS_FILE" "localstack"; then
    echo "Credentials for 'localstack' already exist in $CREDENTIALS_FILE, skipping..."
else
    echo "" >> "$CREDENTIALS_FILE"
    echo "[localstack]" >> "$CREDENTIALS_FILE"
    echo "aws_access_key_id = test" >> "$CREDENTIALS_FILE"
    echo "aws_secret_access_key = test" >> "$CREDENTIALS_FILE"
    echo "Added credentials for 'localstack' to $CREDENTIALS_FILE"
fi

echo ""
echo "✓ LocalStack profile configured successfully!"
echo ""
echo "Usage:"
echo "  aws s3 ls --profile localstack"
echo "  aws lambda list-functions --profile localstack"
echo ""
echo "Or set as default for this session:"
echo "  export AWS_PROFILE=localstack"
echo ""
