# Task-6 Test Results: SQS + Async Processing

**Test Date**: 2026-01-19
**Tester**: Automated Testing
**Duration**: Approximately 15 minutes
**Status**: COMPLETED WITH ISSUES (RESOLVED)

## Executive Summary

Task-6 was successfully tested with all major components working correctly after resolving LocalStack Lambda networking issues. The async processing pipeline (API Gateway -> Lambda -> SQS -> Lambda -> S3) functioned as expected, including DLQ behavior for failed messages.

## Test Environment

- **LocalStack Version**: latest (Docker)
- **AWS Profile**: localstack
- **Region**: us-east-1
- **Lambda Runtime**: python3.9
- **Network**: aws-training-poc_aws-training (Docker bridge)

## Components Tested

### 1. SQS Queue Creation ✓
- **Main Queue**: task-queue
  - Created successfully
  - Visibility timeout: 60 seconds
  - Redrive policy configured with maxReceiveCount=3
- **Dead Letter Queue**: task-dlq
  - Created successfully
  - Received failed messages after 3 retry attempts

### 2. S3 Bucket Creation ✓
- **Bucket Name**: task-results
- Created successfully
- Stored 9 processed task results

### 3. IAM Roles and Policies ✓
- **lambda-sqs-processor role**: Created with permissions for:
  - SQS: ReceiveMessage, DeleteMessage, GetQueueAttributes
  - S3: PutObject
  - CloudWatch Logs
- **lambda-api-enqueue role**: Created with permissions for:
  - SQS: SendMessage
  - CloudWatch Logs

### 4. Lambda Functions

#### Task Processor Lambda ✓
- **Function Name**: task-processor
- **Handler**: task_processor_fixed.handler (modified from original)
- **Timeout**: 120 seconds
- **Status**: Working after networking fix
- **Processed Tasks**: 9 successful, 2 failed (as expected)

#### API Enqueue Lambda ✓
- **Function Name**: api-enqueue
- **Handler**: api_enqueue_fixed.handler (modified from original)
- **Timeout**: 30 seconds
- **Status**: Working after networking fix

### 5. Event Source Mapping ✓
- **UUID**: 85da0510-d4f6-4894-a7b5-4865acf0c84f
- **Batch Size**: 5 messages
- **Max Batching Window**: 10 seconds
- **State**: Enabled
- Successfully connected SQS queue to Lambda processor

### 6. API Gateway ✓
- **API Name**: task-api
- **API ID**: ihrmdqiw1t
- **Stage**: dev
- **Endpoint**: POST /tasks
- **Integration**: AWS_PROXY with api-enqueue Lambda
- Successfully queued all submitted tasks

## Test Cases Executed

### Test Case 1: Direct SQS Message Submission
**Status**: PASS (after fix)
```json
{"task_type": "compute", "data": {"numbers": [100, 200, 300]}}
```
**Result**: Processed successfully, result stored in S3

### Test Case 2: Transform Task via Direct SQS
**Status**: PASS
```json
{"task_type": "transform", "data": {"text": "Hello World from SQS Processing"}}
```
**Result**: Text transformed, stored in S3 with word count and character count

### Test Case 3: API Gateway Integration - Compute Task
**Status**: PASS
- Submitted via POST to API Gateway
- Received 202 Accepted with message_id
- Message queued and processed successfully

### Test Case 4: API Gateway Integration - Transform Task
**Status**: PASS
- Submitted via POST to API Gateway
- Message queued and processed successfully

### Test Case 5: Failed Task for DLQ Testing
**Status**: PASS
```json
{"task_type": "fail", "data": {}}
```
**Result**: 
- Failed 3 times with "Simulated failure for testing DLQ"
- Moved to DLQ after maxReceiveCount reached
- DLQ correctly stored the failed message

### Test Case 6: Bulk Task Submission
**Status**: PASS
- Submitted 5 compute tasks with different number arrays
- All processed successfully
- Results stored in S3 with correct calculations
- Batch processing worked as expected

### Test Case 7: Queue Monitoring
**Status**: PASS
- Main queue metrics showed 0 messages after processing
- DLQ metrics showed failed messages
- Visibility timeout working correctly

### Test Case 8: Resource Cleanup
**Status**: PASS
- All Lambda functions deleted
- Event source mappings removed
- IAM roles and policies cleaned up
- SQS queues deleted
- S3 bucket emptied and deleted
- Local zip files removed

## Sample Results

### Compute Task Result
```json
{
  "task_type": "compute",
  "input": [10, 20, 30],
  "sum": 60,
  "average": 20.0,
  "max": 30,
  "min": 10,
  "message_id": "89794a38-395c-4367-87ee-df96b3d91974",
  "processed_at": "2026-01-19T13:50:45.948917"
}
```

### Transform Task Result
```json
{
  "task_type": "transform",
  "input": "Hello World from SQS Processing",
  "uppercase": "HELLO WORLD FROM SQS PROCESSING",
  "lowercase": "hello world from sqs processing",
  "word_count": 5,
  "char_count": 31,
  "message_id": "48511fcf-6b74-43a9-b724-f262992895e5",
  "processed_at": "2026-01-19T13:48:51.454463"
}
```

## Issues Found and Resolutions

### Issue 1: Lambda Networking with LocalStack (CRITICAL)
**Description**: Lambda functions had hardcoded `endpoint_url='http://localhost:4566'` which doesn't work from within Lambda containers in LocalStack's Docker executor mode.

**Error Message**:
```
EndpointConnectionError: Could not connect to the endpoint URL: "http://localhost:4566/..."
```

**Root Cause**: Lambda containers run in isolated Docker containers and cannot reach `localhost:4566`. They need to use the LocalStack container hostname on the Docker network.

**Resolution**:
1. Modified both Lambda function codes to read endpoint URL from environment variable:
   ```python
   endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localstack:4566')
   ```
2. Set environment variable `AWS_ENDPOINT_URL=http://aws-training-localstack:4566`
3. Used the LocalStack container name for inter-container communication

**Files Modified**:
- Created `task_processor_fixed.py` with environment variable support
- Created `api_enqueue_fixed.py` with environment variable support
- Updated Lambda functions to use new handlers

**Impact**: High - Without this fix, no messages could be processed

### Issue 2: Queue URL Format in API Lambda
**Description**: API Lambda had hardcoded queue URL format that might not match actual LocalStack queue URL.

**Resolution**: Added environment variable support and passed correct queue URL via Lambda configuration.

### Issue 3: SQS Attribute Name Format
**Description**: AWS CLI required attribute names to be passed individually, not comma-separated.

**Error**: `InvalidAttributeName` when trying to pass multiple attributes
**Resolution**: Used `--attribute-names All` and filtered output with grep

## Performance Observations

1. **Message Processing**: Near-instant in LocalStack (faster than real AWS)
2. **Visibility Timeout**: Worked correctly at 60 seconds
3. **Retry Behavior**: Messages retried approximately every 60-65 seconds
4. **Batch Processing**: Lambda received messages in batches as configured
5. **DLQ Transfer**: Occurred after exactly 3 receive attempts

## Success Criteria Review

- [x] SQS queue created with DLQ configuration
- [x] DLQ created for failed messages
- [x] S3 bucket created for results
- [x] Processor Lambda function deployed with SQS permissions
- [x] Event source mapping connects SQS to Lambda
- [x] API Lambda function deployed with SQS send permission
- [x] API Gateway endpoint created for task submission
- [x] POST to API returns 202 (Accepted) status
- [x] Tasks automatically processed by Lambda from queue
- [x] Processing results written to S3
- [x] Failed tasks moved to DLQ after 3 retries
- [x] Multiple tasks processed successfully
- [x] All resources cleaned up successfully

## Recommendations for README

1. **Add LocalStack Lambda Networking Section**: Document the endpoint URL issue and solution
2. **Update Lambda Code**: Modify sample code to use environment variables for endpoints
3. **Add Environment Variable Instructions**: Include steps to set AWS_ENDPOINT_URL for both Lambda functions
4. **Add Troubleshooting Section**: Include common LocalStack Lambda issues and solutions

## Code Changes Required for README

### task_processor.py
```python
# Change from:
s3 = boto3.client('s3', endpoint_url='http://localhost:4566')

# To:
endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
s3 = boto3.client('s3', endpoint_url=endpoint_url)
```

### api_enqueue.py
```python
# Change from:
sqs = boto3.client('sqs', endpoint_url='http://localhost:4566')
QUEUE_URL = 'http://localhost:4566/000000000000/task-queue'

# To:
endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
sqs = boto3.client('sqs', endpoint_url=endpoint_url)
QUEUE_URL = os.environ.get('QUEUE_URL', 'http://localhost:4566/000000000000/task-queue')
```

### Add to Lambda Deployment Commands
```bash
# After creating task-processor function:
aws lambda update-function-configuration \
  --function-name task-processor \
  --environment "Variables={AWS_ENDPOINT_URL=http://aws-training-localstack:4566}"

# After creating api-enqueue function:
QUEUE_URL=$(aws sqs get-queue-url --queue-name task-queue --query 'QueueUrl' --output text)
aws lambda update-function-configuration \
  --function-name api-enqueue \
  --environment "Variables={AWS_ENDPOINT_URL=http://aws-training-localstack:4566,QUEUE_URL=$QUEUE_URL}"
```

## Statistics

- **Total Tasks Submitted**: 10
- **Successfully Processed**: 9
- **Failed (Expected)**: 1 (intentional fail task)
- **Failed (Networking Issue)**: 1 (before fix)
- **Messages in DLQ**: 2 (1 from pre-fix attempt, 1 from intentional fail)
- **S3 Objects Created**: 9
- **Lambda Invocations**: ~15+ (including retries)
- **API Calls**: 8 (5 bulk + 3 individual)

## Conclusion

Task-6 successfully demonstrates async processing with SQS, Lambda, and S3 integration. The main issue encountered was related to LocalStack's Lambda Docker executor networking, which is a common challenge when running Lambda functions in containerized LocalStack environments. After resolving the networking issue, all components worked correctly including:

- Asynchronous task queuing via API Gateway
- Automatic message processing with Lambda event source mapping
- Retry logic with visibility timeout
- Dead letter queue for failed messages
- Result storage in S3
- Proper cleanup of all resources

The exercise provides excellent hands-on experience with serverless async architectures and demonstrates real-world patterns for decoupling API from long-running tasks.
