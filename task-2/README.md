# Exercise 2: Lambda Basics

**Duration**: 20-25 minutes
**Prerequisites**: LocalStack running, AWS CLI configured with localstack profile

**Note**: All commands below assume you've set `export AWS_PROFILE=localstack`. Alternatively, add `--profile localstack` to each command.

## Learning Objectives

By completing this exercise, you will:
- Create and deploy Lambda functions
- Understand the Lambda handler pattern
- Configure environment variables
- Test functions with different event payloads
- View and analyze Lambda execution logs
- Understand function lifecycle and execution context

## Background

AWS Lambda is a serverless compute service that runs code in response to events. Key concepts:

- **Function**: Your code packaged with dependencies
- **Handler**: Entry point function that Lambda calls (e.g., `index.handler`)
- **Event**: JSON input passed to your function
- **Context**: Runtime information about the invocation
- **Environment Variables**: Configuration values available to your function
- **Execution Role**: IAM role that grants permissions to your function

## Tasks

### Task 2.1: Create a Simple Lambda Function

Create a Lambda function that processes JSON events (`lambda_function.py`):
```python
import json
import os

def handler(event, context):
    name = event.get('name', 'World')
    operation = event.get('operation', 'greet')
    greeting = os.environ.get('GREETING', 'Hello')

    if operation == 'greet':
        message = f"{greeting}, {name}!"
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': message,
                'operation': operation
            })
        }
    elif operation == 'farewell':
        message = f"Goodbye, {name}!"
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': message,
                'operation': operation
            })
        }
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': f"Unknown operation: {operation}"
            })
        }
```

### Task 2.2: Package the Function

```bash
zip function.zip lambda_function.py
```

### Task 2.3: Create IAM Role for Lambda

Lambda functions need an execution role to run. Create a basic role:

**Create trust policy** (`trust-policy.json`):
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

**Create the role**:
```bash
aws iam create-role \
  --role-name lambda-basic-execution \
  --assume-role-policy-document file://trust-policy.json
```

**Attach basic execution policy** (allows writing logs):
```bash
aws iam attach-role-policy \
  --role-name lambda-basic-execution \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### Task 2.4: Deploy the Lambda Function

```bash
aws lambda create-function \
  --function-name hello-processor \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-basic-execution \
  --handler lambda_function.handler \
  --zip-file fileb://function.zip \
  --environment Variables={GREETING=Hello}
```

**Note**: In LocalStack, the account ID is always `000000000000`.

**Verify function creation**:
```bash
aws lambda list-functions
```

### Task 2.5: Test the Function

Invoke the function with different event payloads:

**Test 1: Greet operation**
```bash
aws lambda invoke \
  --function-name hello-processor \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name": "Alice", "operation": "greet"}' \
  response.json

cat response.json
```

Expected output:
```json
{"statusCode": 200, "body": "{\"message\": \"Hello, Alice!\", \"operation\": \"greet\"}"}
```

**Test 2: Farewell operation**
```bash
aws lambda invoke \
  --function-name hello-processor \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name": "Bob", "operation": "farewell"}' \
  response.json

cat response.json
```

**Test 3: Invalid operation**
```bash
aws lambda invoke \
  --function-name hello-processor \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name": "Charlie", "operation": "invalid"}' \
  response.json

cat response.json
```

Expected: Error response with status code 400.

### Task 2.6: Update Environment Variables

Update the greeting message:

```bash
aws lambda update-function-configuration \
  --function-name hello-processor \
  --environment Variables={GREETING=Greetings}
```

Wait a moment for the update to complete, then test again:
```bash
aws lambda invoke \
  --function-name hello-processor \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name": "Diana", "operation": "greet"}' \
  response.json

cat response.json
```

The message should now start with "Greetings" instead of "Hello".

### Task 2.7: View Logs

Check the Lambda logs (in LocalStack, logs are sent to CloudWatch Logs):

```bash
aws logs describe-log-groups
```

```bash
aws logs tail /aws/lambda/hello-processor
```

You can also check LocalStack container logs:
```bash
docker logs aws-training-localstack | grep hello-processor
```

## Success Criteria

- [ ] Lambda function created with correct runtime and handler
- [ ] Function successfully deployed with IAM execution role
- [ ] Environment variable configured (GREETING)
- [ ] Function invoked with "greet" operation returns correct response
- [ ] Function invoked with "farewell" operation returns correct response
- [ ] Function invoked with invalid operation returns error (status 400)
- [ ] Environment variable updated and new value reflected in response
- [ ] Function logs accessible via CloudWatch Logs or Docker logs

## Testing Your Work

Run all test cases in sequence:

```bash
aws lambda get-function --function-name hello-processor

aws lambda invoke \
  --function-name hello-processor \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name": "Test", "operation": "greet"}' \
  response.json && cat response.json && echo ""

aws lambda invoke \
  --function-name hello-processor \
  --cli-binary-format raw-in-base64-out \
  --payload '{"name": "Test", "operation": "farewell"}' \
  response.json && cat response.json && echo ""
```

## Common Pitfalls

1. **Incorrect handler format**:
   - Format: `filename.function_name` (e.g., `lambda_function.handler`)
   - The filename should not include the extension

2. **Missing zip file**: Ensure `function.zip` exists before creating the function

3. **Role ARN format**: In LocalStack, always use account ID `000000000000`

4. **Payload format**: The `--payload` parameter expects JSON. Use single quotes to wrap the JSON on the command line.

5. **Function not updating**: After updating code, you need to use `update-function-code`, not `create-function` again.

6. **LocalStack Docker executor**: If functions fail to execute, check that:
   - Docker socket is mounted in `docker-compose.yml`
   - `LAMBDA_EXECUTOR=docker` is set
   - Docker has permission to create containers

## LocalStack-Specific Notes

- Account ID is always `000000000000` in LocalStack
- Lambda execution uses Docker containers (requires Docker socket access)
- Logs appear in both CloudWatch Logs (queryable) and LocalStack container logs
- Cold start behavior may differ from real AWS
- Some advanced features like Lambda layers require specific configuration

## Key Concepts Review

- **Handler**: Entry point for Lambda execution (`module.function_name`)
- **Event**: JSON input passed to function
- **Context**: Runtime information (request ID, remaining time, etc.)
- **Environment Variables**: Configuration accessible via `os.environ`
- **Execution Role**: IAM role granting permissions to Lambda service
- **Synchronous Invocation**: Caller waits for response (as in these tests)
- **Function Configuration**: Runtime, memory, timeout, environment variables

## Extension Challenges

If you finish early, try these:

1. Add error handling and logging to your function
2. Increase function memory and observe behavior
3. Add more operations to the function
4. Create a second function and invoke it from the first (requires additional IAM permissions)

## Next Steps

In Exercise 3, you'll learn about IAM roles and policies in depth, creating roles with least-privilege permissions. In Exercise 4, you'll connect Lambda to S3 to process files automatically.
