# Exercise 3: IAM Roles & Least Privilege

**Duration**: 20-25 minutes
**Prerequisites**: LocalStack running with `ENFORCE_IAM=1`, completed Exercise 1 (S3), AWS CLI configured with localstack profile

**Note**: All commands below assume you've set `export AWS_PROFILE=localstack`. Alternatively, add `--profile localstack` to each command.

## Learning Objectives

By completing this exercise, you will:
- Understand the difference between IAM users and roles
- Create IAM roles with trust policies
- Write least-privilege permission policies
- Apply the principle of least privilege to S3 access
- Test that permissions work as intended
- Understand service principals and role assumption

## Background

IAM (Identity and Access Management) controls who can access AWS resources and what they can do. Key concepts:

- **Principal**: Entity that can make requests (user, service, role)
- **Role**: Identity with permissions that can be assumed temporarily
- **Trust Policy**: Defines who/what can assume the role
- **Permission Policy**: Defines what actions the role can perform
- **Least Privilege**: Grant only the minimum permissions needed
- **Policy Effect**: Allow or Deny access to resources
- **Actions**: API operations (e.g., `s3:GetObject`, `s3:PutObject`)
- **Resources**: Specific AWS resources identified by ARN

## Tasks

### Task 3.1: Understand the Scenario

You'll create a Lambda execution role that has:
- **Read access** to objects in `input/` prefix of an S3 bucket
- **Write access** to objects in `output/` prefix of the same bucket
- **No access** to other prefixes or buckets

This demonstrates least privilege: the function can only read inputs and write outputs, nothing else.

### Task 3.2: Create S3 Bucket for Testing

Create a bucket for this exercise:

```bash
aws s3 mb s3://processing-bucket
```

Upload test files to different prefixes:
```bash
echo "Input data" > input.txt
echo "Existing output" > output.txt
echo "Secret data" > secret.txt

aws s3 cp input.txt s3://processing-bucket/input/file1.txt
aws s3 cp output.txt s3://processing-bucket/output/existing.txt
aws s3 cp secret.txt s3://processing-bucket/secret/confidential.txt
```

### Task 3.3: Create Trust Policy

The trust policy allows Lambda service to assume this role.

**Create `lambda-trust-policy.json`**:
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

Key points:
- `Principal.Service`: Specifies which AWS service can assume the role
- `Action`: `sts:AssumeRole` allows assuming this role
- This is a **trust policy** (who can use the role), not a permission policy (what the role can do)

### Task 3.4: Create Permission Policy with Least Privilege

Create a policy that grants scoped S3 access.

**Create `s3-scoped-policy.json`**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadFromInput",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::processing-bucket/input/*",
        "arn:aws:s3:::processing-bucket"
      ],
      "Condition": {
        "StringLike": {
          "s3:prefix": "input/*"
        }
      }
    },
    {
      "Sid": "WriteToOutput",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::processing-bucket/output/*"
    }
  ]
}
```

Key points:
- **ReadFromInput**: Allows `GetObject` and `ListBucket` only for `input/*` prefix
- **WriteToOutput**: Allows `PutObject` only for `output/*` prefix
- **Condition**: Further restricts ListBucket to the input prefix
- **No access** to `secret/*` or root level objects

### Task 3.5: Create the IAM Role

```bash
aws iam create-role \
  --role-name lambda-s3-processor \
  --assume-role-policy-document file://lambda-trust-policy.json
```

### Task 3.6: Attach the Permission Policy

First, create the policy:
```bash
aws iam create-policy \
  --policy-name S3ScopedAccessPolicy \
  --policy-document file://s3-scoped-policy.json
```

Then attach it to the role:
```bash
aws iam attach-role-policy \
  --role-name lambda-s3-processor \
  --policy-arn arn:aws:iam::000000000000:policy/S3ScopedAccessPolicy
```

**Verify the role**:
```bash
aws iam get-role --role-name lambda-s3-processor
```

**List attached policies**:
```bash
aws iam list-attached-role-policies \
  --role-name lambda-s3-processor
```

### Task 3.7: Create Test Lambda Function

Create a simple function to test the permissions.

**Python version** (`test_permissions.py`):
```python
import json
import os
import boto3

# Lambda runs in a separate Docker container, so we need to use
# LOCALSTACK_HOSTNAME (set by LocalStack) instead of localhost
localstack_host = os.environ.get('LOCALSTACK_HOSTNAME', 'host.docker.internal')
endpoint_url = f'http://{localstack_host}:4566'

s3 = boto3.client('s3', endpoint_url=endpoint_url)

def handler(event, context):
    bucket = 'processing-bucket'
    results = {}

    try:
        response = s3.get_object(Bucket=bucket, Key='input/file1.txt')
        results['read_input'] = 'SUCCESS'
    except Exception as e:
        results['read_input'] = f'FAILED: {str(e)}'

    try:
        s3.put_object(Bucket=bucket, Key='output/test-output.txt', Body=b'Test output')
        results['write_output'] = 'SUCCESS'
    except Exception as e:
        results['write_output'] = f'FAILED: {str(e)}'

    try:
        response = s3.get_object(Bucket=bucket, Key='secret/confidential.txt')
        results['read_secret'] = 'SUCCESS (should be denied!)'
    except Exception as e:
        results['read_secret'] = f'DENIED (expected): {str(e)}'

    return {
        'statusCode': 200,
        'body': json.dumps(results, indent=2)
    }
```

**Package and deploy**:
```bash
zip test-function.zip test_permissions.py

aws lambda create-function \
  --function-name permission-tester \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-s3-processor \
  --handler test_permissions.handler \
  --zip-file fileb://test-function.zip \
  --timeout 30
```

### Task 3.8: Test the Permissions

Invoke the function:
```bash
aws lambda invoke \
  --function-name permission-tester \
  response.json

cat response.json
```

**Expected output**:
```json
{
  "statusCode": 200,
  "body": "{\n  \"read_input\": \"SUCCESS\",\n  \"write_output\": \"SUCCESS\",\n  \"read_secret\": \"DENIED (expected): ...\"\n}"
```

The function should:
- Successfully read from `input/`
- Successfully write to `output/`
- Fail to read from `secret/` (demonstrating least privilege)

**Verify output was written**:
```bash
aws s3 ls s3://processing-bucket/output/
```

You should see `test-output.txt`.

## Success Criteria

- [ ] IAM role created with correct trust policy (allows Lambda service)
- [ ] Permission policy created with scoped S3 access
- [ ] Policy attached to role successfully
- [ ] Test Lambda function created with the role
- [ ] Function can read from `input/` prefix (SUCCESS)
- [ ] Function can write to `output/` prefix (SUCCESS)
- [ ] Function cannot read from `secret/` prefix (DENIED)
- [ ] Output file appears in S3 after function execution

## Testing Your Work

Comprehensive test:
```bash
aws iam get-role --role-name lambda-s3-processor

aws iam list-attached-role-policies --role-name lambda-s3-processor

aws lambda invoke \
  --function-name permission-tester \
  response.json && cat response.json

aws s3 ls s3://processing-bucket/ --recursive
```

## Common Pitfalls

1. **Policy Resource ARN format**:
   - Bucket: `arn:aws:s3:::bucket-name`
   - Objects: `arn:aws:s3:::bucket-name/prefix/*`
   - Must include `/*` for objects in a prefix

2. **Action naming**: Actions must match the service format exactly (e.g., `s3:GetObject`, not `s3:get-object`)

3. **Condition keys**: Conditions are case-sensitive and service-specific. Check AWS documentation for valid keys.

4. **ListBucket vs GetObject**:
   - `ListBucket` operates on the bucket resource
   - `GetObject` operates on object resources
   - They require different Resource ARNs in the policy

5. **ENFORCE_IAM**: If permissions work when they shouldn't, verify `ENFORCE_IAM=1` in docker-compose.yml

6. **Policy evaluation**: Explicit Deny always wins. No Allow means implicit Deny.

## LocalStack-Specific Notes

- IAM enforcement requires `ENFORCE_IAM=1` environment variable
- Account ID is always `000000000000` in LocalStack
- Some advanced IAM features may not be fully implemented
- Policy evaluation may be simpler than in real AWS
- Useful for testing basic permission scenarios
- **IAM enforcement limitations**: LocalStack's IAM enforcement may not fully replicate AWS behavior. In some cases, the test Lambda function may be able to access resources that should be denied by the policy (e.g., reading from the `secret/` prefix). This is a known limitation of LocalStack's IAM implementation. In a production AWS environment, the same IAM policy would properly enforce access restrictions.

## Key Concepts Review

- **Trust Policy** (AssumeRole policy): Who can use this role
- **Permission Policy**: What actions this role can perform
- **Least Privilege**: Grant minimum required permissions
- **Resource ARN**: Identifies specific AWS resources
- **Policy Statement**: Single permission rule (Effect, Action, Resource)
- **Condition**: Additional constraints on when policy applies
- **Service Principal**: AWS service that can assume a role (e.g., `lambda.amazonaws.com`)

## Policy Design Principles

1. **Start with Deny All**: IAM denies by default, add only needed permissions
2. **Scope Actions**: Use specific actions (`s3:GetObject`) rather than wildcards (`s3:*`)
3. **Scope Resources**: Limit to specific buckets/prefixes, not all resources (`*`)
4. **Use Conditions**: Add constraints like IP ranges, time windows, or prefixes
5. **Test Denials**: Verify permissions don't grant access they shouldn't
6. **Separate Roles**: Different functions should have different roles

## Extension Challenges

If you finish early:

1. Add a policy statement that allows deleting objects from `output/` only
2. Create a second role with read-only access to entire bucket
3. Add a condition that restricts access to specific file types
4. Test with inline policies instead of managed policies

## Next Steps

In Exercise 4, you'll use IAM roles with S3 event notifications to create an event-driven Lambda function that processes files automatically when uploaded.
