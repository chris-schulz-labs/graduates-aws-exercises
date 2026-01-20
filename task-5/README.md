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

The required IAM policies are provided in:
- `lambda-trust-policy.json` - Trust policy allowing Lambda to assume the role
- `api-lambda-policy.json` - Permission policy granting S3 and CloudWatch Logs access

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

The Lambda function implementation is provided in `api_handler.py`. It handles all API operations:
- `list_items()` - GET /items - Lists all items from S3
- `get_item(item_id)` - GET /items/{id} - Retrieves a specific item
- `create_item(body)` - POST /items - Creates a new item with UUID
- `delete_item(item_id)` - DELETE /items/{id} - Deletes an item
- `response(status_code, body)` - Helper to format API Gateway responses

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
  -d '{"name": "Item 1", "description": "First item"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")

ITEM2=$(curl -s -X POST "http://localhost:4566/restapis/$API_ID/dev/_user_request_/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Item 2", "description": "Second item"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")

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
