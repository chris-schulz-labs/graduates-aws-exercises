#!/bin/bash

set -e

PROFILE="localstack"
BUCKET_NAME="api-data-store"
ROLE_NAME="lambda-api-role"
POLICY_NAME="ApiLambdaPolicy"
FUNCTION_NAME="api-handler"
API_NAME="items-api"

echo "=== Exercise 5: API Gateway + Lambda REST API Solution ==="
echo ""

echo "Step 1: Creating S3 bucket for data storage..."
aws --profile $PROFILE s3 mb s3://$BUCKET_NAME
echo "✓ Bucket created"
echo ""

echo "Step 2: Creating IAM role..."
aws --profile $PROFILE iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://lambda-trust-policy.json

aws --profile $PROFILE iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://api-lambda-policy.json

aws --profile $PROFILE iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::000000000000:policy/$POLICY_NAME
echo "✓ Role and policy created"
echo ""

echo "Step 3: Packaging and deploying Lambda function..."
zip function.zip api_handler.py

aws --profile $PROFILE lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/$ROLE_NAME \
  --handler api_handler.handler \
  --zip-file fileb://function.zip \
  --timeout 30
echo "✓ Function deployed"
echo ""

echo "Step 4: Creating REST API..."
aws --profile $PROFILE apigateway create-rest-api \
  --name $API_NAME \
  --description "Items REST API"

API_ID=$(aws --profile $PROFILE apigateway get-rest-apis \
  --query "items[?name=='$API_NAME'].id" --output text)
echo "✓ API created with ID: $API_ID"
echo ""

echo "Step 5: Getting root resource..."
ROOT_ID=$(aws --profile $PROFILE apigateway get-resources \
  --rest-api-id $API_ID --query 'items[0].id' --output text)
echo "✓ Root resource ID: $ROOT_ID"
echo ""

echo "Step 6: Creating /items resource..."
ITEMS_RESOURCE_ID=$(aws --profile $PROFILE apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part items \
  --query 'id' --output text)
echo "✓ Items resource ID: $ITEMS_RESOURCE_ID"
echo ""

echo "Step 7: Creating /items/{id} resource..."
ITEM_RESOURCE_ID=$(aws --profile $PROFILE apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ITEMS_RESOURCE_ID \
  --path-part '{id}' \
  --query 'id' --output text)
echo "✓ Item resource ID: $ITEM_RESOURCE_ID"
echo ""

echo "Step 8: Creating methods..."
aws --profile $PROFILE apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE

aws --profile $PROFILE apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE

aws --profile $PROFILE apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE \
  --request-parameters method.request.path.id=true

aws --profile $PROFILE apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method DELETE \
  --authorization-type NONE \
  --request-parameters method.request.path.id=true
echo "✓ Methods created"
echo ""

echo "Step 9: Configuring Lambda integrations..."
LAMBDA_ARN="arn:aws:lambda:us-east-1:000000000000:function:$FUNCTION_NAME"

aws --profile $PROFILE apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

aws --profile $PROFILE apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEMS_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

aws --profile $PROFILE apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

aws --profile $PROFILE apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ITEM_RESOURCE_ID \
  --http-method DELETE \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"
echo "✓ Integrations configured"
echo ""

echo "Step 10: Deploying API to dev stage..."
aws --profile $PROFILE apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev
echo "✓ API deployed"
echo ""

BASE_URL="http://localhost:4566/restapis/$API_ID/dev/_user_request_"
echo "API Base URL: $BASE_URL"
echo ""

echo "Step 11: Testing API endpoints..."
echo ""

echo "Test 1: List items (should be empty)..."
curl -s -X GET "$BASE_URL/items" | python3 -m json.tool || echo "Failed"
echo ""

echo "Test 2: Create first item..."
RESPONSE1=$(curl -s -X POST "$BASE_URL/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Laptop", "description": "Dell XPS 13"}')
echo "$RESPONSE1" | python3 -m json.tool || echo "Failed"
ITEM1_ID=$(echo "$RESPONSE1" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo ""

echo "Test 3: Create second item..."
RESPONSE2=$(curl -s -X POST "$BASE_URL/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "Mouse", "description": "Logitech MX Master"}')
echo "$RESPONSE2" | python3 -m json.tool || echo "Failed"
ITEM2_ID=$(echo "$RESPONSE2" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
echo ""

echo "Test 4: List all items (should show 2 items)..."
curl -s -X GET "$BASE_URL/items" | python3 -m json.tool || echo "Failed"
echo ""

echo "Test 5: Get specific item..."
curl -s -X GET "$BASE_URL/items/$ITEM1_ID" | python3 -m json.tool || echo "Failed"
echo ""

echo "Test 6: Delete an item..."
curl -s -X DELETE "$BASE_URL/items/$ITEM1_ID" | python3 -m json.tool || echo "Failed"
echo ""

echo "Test 7: List items after deletion (should show 1 item)..."
curl -s -X GET "$BASE_URL/items" | python3 -m json.tool || echo "Failed"
echo ""

echo "Test 8: Try to get deleted item (should return 404)..."
curl -s -X GET "$BASE_URL/items/$ITEM1_ID" | python3 -m json.tool || echo "Failed"
echo ""

echo "=== All steps completed successfully! ==="
echo ""
echo "Summary:"
echo "- API ID: $API_ID"
echo "- Base URL: $BASE_URL"
echo "- Endpoints:"
echo "  GET    $BASE_URL/items"
echo "  POST   $BASE_URL/items"
echo "  GET    $BASE_URL/items/{id}"
echo "  DELETE $BASE_URL/items/{id}"
