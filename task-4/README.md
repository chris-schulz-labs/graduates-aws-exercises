# Exercise 4: Lambda + S3 Event Processing

**Duration**: 25-30 minutes
**Prerequisites**: Completed Exercises 1-3, understand S3, Lambda, and IAM, AWS CLI configured with localstack profile

**Note**: All commands below assume you've set `export AWS_PROFILE=localstack`. Alternatively, add `--profile localstack` to each command.

## Learning Objectives

By completing this exercise, you will:
- Configure S3 event notifications to trigger Lambda functions
- Process S3 events in Lambda (parse event structure)
- Read objects from S3 within Lambda
- Transform data and write results back to S3
- Implement proper IAM permissions for S3 access
- Avoid common pitfalls like infinite event loops

## Background

Event-driven architecture allows systems to react to changes automatically. When a file is uploaded to S3, an event notification can trigger a Lambda function to process it.

**Key Concepts**:
- **Event Source**: S3 bucket generating events
- **Event Notification**: Configuration telling S3 which events to send where
- **Event Structure**: JSON containing bucket name, object key, event type
- **Asynchronous Processing**: Lambda runs in response to events, not user requests
- **Idempotency**: Functions should handle duplicate events gracefully

**Common Use Cases**:
- Image thumbnail generation
- File format conversion
- Data validation and enrichment
- Log processing and analysis
- Triggering downstream workflows

## Tasks

### Task 4.1: Create S3 Bucket

Create a bucket for event-driven processing:

```bash
aws s3 mb s3://event-processing-bucket
```

### Task 4.2: Create IAM Role with S3 Permissions

Create a role that allows Lambda to read from `input/` and write to `output/`.

**Trust policy** (`lambda-trust-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Permission policy** (`s3-event-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::event-processing-bucket/input/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::event-processing-bucket/output/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

**Create role and attach policy**:
```bash
aws iam create-role \
  --role-name lambda-s3-event-processor \
  --assume-role-policy-document file://lambda-trust-policy.json

aws iam create-policy \
  --policy-name S3EventProcessingPolicy \
  --policy-document file://s3-event-policy.json

aws iam attach-role-policy \
  --role-name lambda-s3-event-processor \
  --policy-arn arn:aws:iam::000000000000:policy/S3EventProcessingPolicy
```

### Task 4.3: Create Lambda Function to Process S3 Events

Create a function that reads uploaded files, transforms them, and writes results.

Create `s3_processor.py`:
```python
import json
import boto3
from datetime import datetime

s3 = boto3.client('s3', endpoint_url='http://localhost:4566')

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        event_name = record['eventName']

        print(f"Processing {event_name} for {bucket}/{key}")

        if not key.startswith('input/'):
            print(f"Ignoring object not in input/: {key}")
            continue

        try:
            response = s3.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')

            processed_content = {
                'original_file': key,
                'processed_at': datetime.utcnow().isoformat(),
                'original_content': content,
                'word_count': len(content.split()),
                'character_count': len(content),
                'uppercase_content': content.upper()
            }

            output_key = key.replace('input/', 'output/')
            output_key = output_key.replace('.txt', '-processed.json')

            s3.put_object(
                Bucket=bucket,
                Key=output_key,
                Body=json.dumps(processed_content, indent=2),
                ContentType='application/json'
            )

            print(f"Successfully processed {key} -> {output_key}")

        except Exception as e:
            print(f"Error processing {key}: {str(e)}")
            raise

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete')
    }
```

**Package and deploy**:
```bash
zip function.zip s3_processor.py

aws lambda create-function \
  --function-name s3-event-processor \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-s3-event-processor \
  --handler s3_processor.handler \
  --zip-file fileb://function.zip \
  --timeout 60
```

### Task 4.4: Grant S3 Permission to Invoke Lambda

S3 needs permission to invoke your Lambda function:

```bash
aws lambda add-permission \
  --function-name s3-event-processor \
  --statement-id s3-invoke-permission \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::event-processing-bucket
```

### Task 4.5: Configure S3 Event Notification

Create notification configuration (`notification-config.json`):
```json
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:s3-event-processor",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "input/"
            }
          ]
        }
      }
    }
  ]
}
```

Apply the configuration:
```bash
aws s3api put-bucket-notification-configuration \
  --bucket event-processing-bucket \
  --notification-configuration file://notification-config.json
```

**Verify configuration**:
```bash
aws s3api get-bucket-notification-configuration \
  --bucket event-processing-bucket
```

### Task 4.6: Test the Event-Driven Processing

Upload a file to trigger processing:

```bash
echo "Hello from S3 event processing" > test-input.txt

aws s3 cp test-input.txt \
  s3://event-processing-bucket/input/test-input.txt
```

Wait a moment for processing, then check for output:

```bash
aws s3 ls s3://event-processing-bucket/output/
```

You should see `test-input-processed.json`.

**Download and verify the processed file**:
```bash
aws s3 cp \
  s3://event-processing-bucket/output/test-input-processed.json \
  result.json

cat result.json
```

Expected content includes original text, word count, character count, and uppercase version.

**Check Lambda logs**:
```bash
aws logs tail /aws/lambda/s3-event-processor
```

### Task 4.7: Test with Multiple Files

Upload multiple files at once:

```bash
echo "First file content" > file1.txt
echo "Second file with more content" > file2.txt
echo "Third file here" > file3.txt

aws s3 cp file1.txt s3://event-processing-bucket/input/file1.txt
aws s3 cp file2.txt s3://event-processing-bucket/input/file2.txt
aws s3 cp file3.txt s3://event-processing-bucket/input/file3.txt
```

Verify all were processed:
```bash
aws s3 ls s3://event-processing-bucket/output/
```

## Success Criteria

- [ ] S3 bucket created with input/ and output/ prefixes
- [ ] IAM role created with permissions to read from input/ and write to output/
- [ ] Lambda function deployed with S3 event processing logic
- [ ] S3 granted permission to invoke Lambda function
- [ ] Event notification configured for ObjectCreated events on input/ prefix
- [ ] Uploading file to input/ triggers Lambda automatically
- [ ] Processed JSON file appears in output/ prefix
- [ ] Processed file contains correct data (word count, uppercase text, etc.)
- [ ] Multiple files processed successfully
- [ ] No infinite loops (output/ doesn't trigger new events)

## Testing Your Work

```bash
aws s3api get-bucket-notification-configuration \
  --bucket event-processing-bucket

echo "Test content for validation" > validation.txt
aws s3 cp validation.txt \
  s3://event-processing-bucket/input/validation.txt

sleep 2

aws s3 ls s3://event-processing-bucket/output/

aws s3 cp \
  s3://event-processing-bucket/output/validation-processed.json - | cat
```

## Common Pitfalls

1. **Infinite event loops**: If output files trigger new events, you'll create an infinite loop. Always use prefix filters to ensure processed files don't retrigger processing.

2. **Permission errors**: Ensure both IAM role (Lambda's execution role) and resource policy (S3's permission to invoke Lambda) are configured.

3. **Event structure parsing**: S3 events contain an array of Records. Always iterate through `event['Records']`.

4. **Missing endpoint URL**: When creating boto3/AWS SDK clients in Lambda for LocalStack, specify the endpoint URL.

5. **Asynchronous nature**: S3 event invocations are asynchronous. There may be a short delay between upload and processing.

6. **Large files**: Lambda has memory and timeout limits. Large file processing may require streaming or splitting work.

## LocalStack-Specific Notes

- Event delivery is nearly instant in LocalStack (faster than real AWS)
- Ensure Lambda can access LocalStack from within Docker container
- Check LocalStack logs if events aren't being delivered: `docker logs aws-training-localstack`
- S3 notifications work the same as in real AWS for basic scenarios

## Key Concepts Review

- **Event Notification**: S3 configuration to send events to Lambda, SNS, or SQS
- **Event Structure**: Standardized JSON format with Records array
- **Filter Rules**: Prefix/suffix filters to limit which objects trigger events
- **Resource Policy**: Permission allowing S3 to invoke Lambda
- **Execution Role**: IAM role granting Lambda permissions to access S3
- **Asynchronous Invocation**: Lambda invoked by S3 in fire-and-forget mode
- **Event Source Mapping**: Connection between event source and Lambda function

## Extension Challenges

If you finish early:

1. Add error handling to write failed files to an `error/` prefix
2. Process only specific file types (e.g., .txt files)
3. Implement deduplication to handle duplicate events
4. Add CloudWatch metrics to track processing statistics
5. Create a second Lambda to process the JSON outputs

## Next Steps

In Exercise 5, you'll build a REST API with API Gateway and Lambda, implementing synchronous request-response patterns. In Exercise 6, you'll use SQS for more robust asynchronous processing with retry logic.
