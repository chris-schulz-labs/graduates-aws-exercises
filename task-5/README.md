# Exercise 5: API Gateway + Lambda REST API

**Duration**: 25-30 minutes
**Prerequisites**: Completed Exercises 1-4, understand Lambda and S3, AWS CLI configured with localstack profile

**Note**: All commands below assume you've set `export AWS_PROFILE=localstack`. Alternatively, add `--profile localstack` to each command.

## Learning Objectives

By completing this exercise, you will:
- Create a REST API with API Gateway
- Integrate API Gateway with Lambda functions (Lambda proxy integration)
- Implement CRUD operations (Create, Read, Delete)
- Handle HTTP methods (GET, POST, DELETE)
- Parse request parameters and body
- Return proper HTTP status codes and responses
- Use S3 as a data store for API
- Test REST API endpoints with curl or similar tools

## Background

API Gateway allows you to create HTTP APIs that trigger Lambda functions. This enables building serverless REST APIs without managing servers.

**Key Concepts**:
- **REST API**: V1 REST API (supported in LocalStack free tier)
- **Resource**: URL path (e.g., `/items`, `/items/{id}`)
- **Method**: HTTP verb (GET, POST, PUT, DELETE)
- **Lambda Proxy Integration**: API Gateway passes full request to Lambda
- **Request/Response Mapping**: Lambda receives event with headers, body, path params
- **Status Codes**: 200 (OK), 201 (Created), 404 (Not Found), 400 (Bad Request)

**Use Cases**:
- Web application backends
- Mobile app APIs
- Microservices
- Data access layers

## Tasks

### Task 5.1: Create S3 Bucket for Data Storage

We'll use S3 to store items (simple key-value storage):

```bash
aws s3 mb s3://api-data-store
```

### Task 5.2: Create IAM Role for Lambda

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

**Permission policy** (`api-lambda-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::api-data-store",
        "arn:aws:s3:::api-data-store/*"
      ]
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

**Create role**:
```bash
aws iam create-role \
  --role-name lambda-api-role \
  --assume-role-policy-document file://lambda-trust-policy.json

aws iam create-policy \
  --policy-name ApiLambdaPolicy \
  --policy-document file://api-lambda-policy.json

aws iam attach-role-policy \
  --role-name lambda-api-role \
  --policy-arn arn:aws:iam::000000000000:policy/ApiLambdaPolicy
```

### Task 5.3: Create Lambda Functions for API

Create Lambda function to handle all API operations.

**Python version** (`api_handler.py`):
```python
import json
import boto3
import uuid
from datetime import datetime

s3 = boto3.client('s3', endpoint_url='http://localhost:4566')
BUCKET = 'api-data-store'

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    http_method = event['httpMethod']
    path = event['path']
    path_parameters = event.get('pathParameters') or {}
    body = event.get('body')

    if http_method == 'GET' and path == '/items':
        return list_items()
    elif http_method == 'GET' and path.startswith('/items/'):
        item_id = path_parameters.get('id')
        return get_item(item_id)
    elif http_method == 'POST' and path == '/items':
        return create_item(body)
    elif http_method == 'DELETE' and path.startswith('/items/'):
        item_id = path_parameters.get('id')
        return delete_item(item_id)
    else:
        return response(404, {'error': 'Not found'})

def list_items():
    try:
        result = s3.list_objects_v2(Bucket=BUCKET, Prefix='items/')
        items = []

        if 'Contents' in result:
            for obj in result['Contents']:
                key = obj['Key']
                if key != 'items/':
                    item_data = s3.get_object(Bucket=BUCKET, Key=key)
                    item = json.loads(item_data['Body'].read().decode('utf-8'))
                    items.append(item)

        return response(200, {'items': items, 'count': len(items)})
    except Exception as e:
        return response(500, {'error': str(e)})

def get_item(item_id):
    if not item_id:
        return response(400, {'error': 'Missing item ID'})

    try:
        key = f'items/{item_id}.json'
        result = s3.get_object(Bucket=BUCKET, Key=key)
        item = json.loads(result['Body'].read().decode('utf-8'))
        return response(200, item)
    except s3.exceptions.NoSuchKey:
        return response(404, {'error': 'Item not found'})
    except Exception as e:
        return response(500, {'error': str(e)})

def create_item(body):
    if not body:
        return response(400, {'error': 'Missing request body'})

    try:
        data = json.loads(body)
        item_id = str(uuid.uuid4())

        item = {
            'id': item_id,
            'name': data.get('name', 'Unnamed'),
            'description': data.get('description', ''),
            'created_at': datetime.utcnow().isoformat()
        }

        key = f'items/{item_id}.json'
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps(item),
            ContentType='application/json'
        )

        return response(201, item)
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        return response(500, {'error': str(e)})

def delete_item(item_id):
    if not item_id:
        return response(400, {'error': 'Missing item ID'})

    try:
        key = f'items/{item_id}.json'
        s3.head_object(Bucket=BUCKET, Key=key)
        s3.delete_object(Bucket=BUCKET, Key=key)
        return response(200, {'message': 'Item deleted', 'id': item_id})
    except s3.exceptions.ClientError as e:
        if e.response['Error']['Code'] == '404':
            return response(404, {'error': 'Item not found'})
        return response(500, {'error': str(e)})
    except Exception as e:
        return response(500, {'error': str(e)})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(body)
    }
```

**Package and deploy**:
```bash
zip function.zip api_handler.py

aws lambda create-function \
  --function-name api-handler \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-api-role \
  --handler api_handler.handler \
  --zip-file fileb://function.zip \
  --timeout 30
```

### Task 5.4: Create REST API with API Gateway

```bash
aws apigateway create-rest-api \
  --name items-api \
  --description "Items REST API"
```

Save the API ID from the output (you'll need it for subsequent commands).

**Set API ID as variable**:
```bash
API_ID=$(aws apigateway get-rest-apis \
  --query 'items[?name==`items-api`].id' --output text)
echo "API ID: $API_ID"
```

**Get root resource ID**:
```bash
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID --query 'items[0].id' --output text)
echo "Root Resource ID: $ROOT_ID"
```

### Task 5.5: Create Resources and Methods

**Create /items resource**:
```bash
ITEMS_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part items \
  --query 'id' --output text)
echo "Items Resource ID: $ITEMS_RESOURCE_ID"
```

**Create /items/{id} resource**:
```bash
ITEM_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ITEMS_RESOURCE_ID \
  --path-part '{id}' \
  --query 'id' --output text)
echo "Item Resource ID: $ITEM_RESOURCE_ID"
```

**Create GET method for /items**:
```bash
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE
```

**Create POST method for /items**:
```bash
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE
```

**Create GET method for /items/{id}**:
```bash
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE \
  --request-parameters method.request.path.id=true
```

**Create DELETE method for /items/{id}**:
```bash
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method DELETE \
  --authorization-type NONE \
  --request-parameters method.request.path.id=true
```

### Task 5.6: Configure Lambda Integration

Get Lambda ARN:
```bash
LAMBDA_ARN="arn:aws:lambda:us-east-1:000000000000:function:api-handler"
```

**Integrate GET /items**:
```bash
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"
```

**Integrate POST /items**:
```bash
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"
```

**Integrate GET /items/{id}**:
```bash
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"
```

**Integrate DELETE /items/{id}**:
```bash
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method DELETE \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"
```

### Task 5.7: Deploy the API

```bash
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev
```

Your API is now available at:
```
http://localhost:4566/restapis/$API_ID/dev/_user_request_/items
```

### Task 5.8: Test the REST API

**List items (initially empty)**:
```bash
curl -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items"
```

**Create an item**:
```bash
curl -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "This is a test item"}'
```

Save the returned `id` value.

**Get specific item** (replace `<ITEM_ID>` with actual ID):
```bash
curl -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items/<ITEM_ID>"
```

**List all items**:
```bash
curl -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items"
```

**Delete an item**:
```bash
curl -X DELETE "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items/<ITEM_ID>"
```

**Verify deletion**:
```bash
curl -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items"
```

## Success Criteria

- [ ] S3 bucket created for data storage
- [ ] IAM role with S3 permissions created
- [ ] Lambda function deployed with CRUD logic
- [ ] REST API created in API Gateway
- [ ] Resources created: /items and /items/{id}
- [ ] Methods created: GET /items, POST /items, GET /items/{id}, DELETE /items/{id}
- [ ] Lambda proxy integration configured for all methods
- [ ] API deployed to 'dev' stage
- [ ] GET /items returns empty list initially
- [ ] POST /items creates item and returns 201 with item data
- [ ] GET /items/{id} retrieves specific item
- [ ] GET /items shows all created items
- [ ] DELETE /items/{id} removes item
- [ ] GET after DELETE shows item removed

## Testing Your Work

```bash
echo "Creating items..."
ITEM1=$(curl -s -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Item 1", "description": "First item"}' | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

ITEM2=$(curl -s -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Item 2", "description": "Second item"}' | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

echo "Listing all items..."
curl -s -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items"

echo "Getting specific item..."
curl -s -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items/$ITEM1"

echo "Deleting item..."
curl -s -X DELETE "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items/$ITEM1"

echo "Final list..."
curl -s -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items"
```

## Common Pitfalls

1. **AWS_PROXY integration**: Use `AWS_PROXY` type for Lambda proxy integration, not `AWS`

2. **Integration HTTP method**: Always use POST for Lambda integrations, regardless of the API method

3. **URI format**: Must be exact: `arn:aws:apigateway:region:lambda:path/2015-03-31/functions/LAMBDA_ARN/invocations`

4. **Path parameters**: Resource path `{id}` must match parameter name in request

5. **Deployment required**: After creating/modifying methods, you must deploy the API

6. **LocalStack URL format**: Use `/restapis/API_ID/STAGE/_user_request_/PATH` for LocalStack

7. **Response format**: Lambda must return object with `statusCode`, `headers`, and `body` for proxy integration

## LocalStack-Specific Notes

- Use V1 REST API (create-rest-api), not V2 HTTP API
- API endpoint format: `http://localhost:4566/restapis/{api-id}/{stage}/_user_request_/{path}`
- In real AWS, URL format is: `https://{api-id}.execute-api.{region}.amazonaws.com/{stage}/{path}`
- IAM authorization may be simplified compared to real AWS
- Custom domains not available in free tier

## Key Concepts Review

- **REST API**: V1 API Gateway providing full REST capabilities
- **Resource**: URL path segment in API structure
- **Method**: HTTP verb (GET, POST, PUT, DELETE) on a resource
- **Lambda Proxy Integration**: Passes full request to Lambda, expects formatted response
- **Path Parameters**: Variable segments in URL (e.g., {id})
- **Request/Response Mapping**: Transformation between HTTP and Lambda formats
- **Deployment**: Publishing API to a stage (dev, prod, etc.)
- **Stage**: Environment for API (dev, staging, prod)

## Extension Challenges

If you finish early:

1. Add PUT method for updating items
2. Implement query parameters for filtering items
3. Add request validation to API Gateway
4. Implement pagination for large result sets
5. Add CloudWatch metrics and alarms

## Next Steps

In Exercise 6, you'll use SQS to decouple the API from processing, implementing asynchronous patterns with message queues and dead-letter queues.
