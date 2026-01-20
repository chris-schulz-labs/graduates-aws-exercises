# Task 9: End-to-End Application - E-Commerce Order System

## Objectives

Build a complete serverless e-commerce order processing system that integrates multiple AWS services. This capstone exercise demonstrates real-world architecture patterns combining API Gateway, Lambda, DynamoDB, S3, SQS, and Step Functions.

## Application Overview

You'll build an order processing system with these features:

- **REST API** for order submission and retrieval
- **Order validation** and inventory checking
- **Async processing** using message queues
- **Data persistence** in DynamoDB
- **Receipt storage** in S3
- **Workflow orchestration** with Step Functions
- **Error handling** and retry logic

## Architecture

```
User Request
    ↓
API Gateway → Submit Order Lambda
    ↓
DynamoDB (Orders table)
    ↓
SQS Queue (order-processing-queue)
    ↓
Process Order Lambda → Step Functions
    ↓
├─ Validate Order
├─ Check Inventory (DynamoDB)
├─ Process Payment (mock)
└─ Generate Receipt → S3
    ↓
Update Order Status (DynamoDB)
    ↓
Success/Failure
```

## Components

### 1. DynamoDB Tables
- **Orders**: Store order details
- **Inventory**: Track product availability

### 2. Lambda Functions
- **submit-order**: Accept orders via API
- **process-order**: Process orders from SQS
- **get-order**: Retrieve order by ID
- **list-orders**: List all orders

### 3. Step Functions
- **order-workflow**: Orchestrate order processing steps

### 4. S3 Bucket
- **receipts**: Store order receipts

### 5. SQS Queue
- **order-processing-queue**: Async order processing

### 6. API Gateway
- **OrderAPI**: REST endpoints

## Prerequisites

- Completed Tasks 1-8
- LocalStack running with all services enabled
- AWS CLI configured with localstack profile

## Exercise Steps

### Step 1: Create DynamoDB Tables

**Orders table**:

```bash
aws dynamodb create-table \
    --table-name Orders \
    --attribute-definitions \
        AttributeName=orderId,AttributeType=S \
        AttributeName=customerId,AttributeType=S \
    --key-schema \
        AttributeName=orderId,KeyType=HASH \
    --global-secondary-indexes \
        '[{
            "IndexName": "CustomerIndex",
            "KeySchema": [{"AttributeName":"customerId","KeyType":"HASH"}],
            "Projection": {"ProjectionType":"ALL"},
            "ProvisionedThroughput": {"ReadCapacityUnits":5,"WriteCapacityUnits":5}
        }]' \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Inventory table**:

```bash
aws dynamodb create-table \
    --table-name Inventory \
    --attribute-definitions \
        AttributeName=productId,AttributeType=S \
    --key-schema \
        AttributeName=productId,KeyType=HASH \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Add sample inventory**:

```bash
aws dynamodb put-item \
    --table-name Inventory \
    --item '{
        "productId": {"S": "PROD-001"},
        "name": {"S": "Laptop"},
        "price": {"N": "999.99"},
        "stock": {"N": "10"}
    }' \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws dynamodb put-item \
    --table-name Inventory \
    --item '{
        "productId": {"S": "PROD-002"},
        "name": {"S": "Mouse"},
        "price": {"N": "29.99"},
        "stock": {"N": "50"}
    }' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 2: Create S3 Bucket

```bash
aws s3 mb s3://order-receipts \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 3: Create SQS Queue

```bash
aws sqs create-queue \
    --queue-name order-processing-queue \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

Get queue URL:

```bash
aws sqs get-queue-url \
    --queue-name order-processing-queue \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 4: Create Lambda Functions

See the Lambda function implementations:

**API Functions:**
- [submit_order.py](submit_order.py) - API endpoint to submit orders
- [get_order.py](get_order.py) - Retrieve order by ID
- [list_orders.py](list_orders.py) - List all orders

**Processing Functions:**
- [process_order.py](process_order.py) - Process orders from SQS and invoke Step Functions

**Step Functions Workflow Steps:**
- [validate_order_step.py](validate_order_step.py) - Validate order and check inventory
- [process_payment_step.py](process_payment_step.py) - Process payment (mock)
- [generate_receipt_step.py](generate_receipt_step.py) - Generate and store receipt in S3
- [update_order_status_step.py](update_order_status_step.py) - Update order status in DynamoDB

### Step 5: Create Step Functions Workflow

**order-processing-workflow.json**:

```json
{
  "Comment": "E-commerce order processing workflow",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:validate-order-step",
      "ResultPath": "$.validation",
      "Next": "CheckValidation",
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "OrderFailed",
        "ResultPath": "$.error"
      }]
    },
    "CheckValidation": {
      "Type": "Choice",
      "Choices": [{
        "Variable": "$.validation.valid",
        "BooleanEquals": true,
        "Next": "ProcessPayment"
      }],
      "Default": "OrderFailed"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:process-payment-step",
      "ResultPath": "$.payment",
      "Retry": [{
        "ErrorEquals": ["States.TaskFailed"],
        "IntervalSeconds": 2,
        "MaxAttempts": 3,
        "BackoffRate": 2.0
      }],
      "Catch": [{
        "ErrorEquals": ["States.ALL"],
        "Next": "PaymentFailed",
        "ResultPath": "$.error"
      }],
      "Next": "GenerateReceipt"
    },
    "GenerateReceipt": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:generate-receipt-step",
      "ResultPath": "$.receipt",
      "Next": "UpdateOrderStatus"
    },
    "UpdateOrderStatus": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:update-order-status-step",
      "End": true
    },
    "PaymentFailed": {
      "Type": "Pass",
      "Result": {
        "status": "payment_failed"
      },
      "Next": "OrderFailed"
    },
    "OrderFailed": {
      "Type": "Fail",
      "Error": "OrderProcessingError",
      "Cause": "Order processing failed"
    }
  }
}
```

### Step 6: Create API Gateway

```bash
aws apigateway create-rest-api \
    --name OrderAPI \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

Get API ID:

```bash
API_ID=$(aws apigateway get-rest-apis \
    --endpoint-url http://localhost:4566 \
    --profile localstack \
    --query 'items[?name==`OrderAPI`].id' \
    --output text)
```

Create resources and methods (see deploy script for full setup).

### Step 7: Test the Application

**Submit an order**:

```bash
curl -X POST http://localhost:4566/restapis/$API_ID/prod/_user_request_/orders \
    -H "Content-Type: application/json" \
    -d '{
        "customerId": "CUST-001",
        "productId": "PROD-001",
        "quantity": 2
    }'
```

**Get order status**:

```bash
curl http://localhost:4566/restapis/$API_ID/prod/_user_request_/orders/{orderId}
```

**List all orders**:

```bash
curl http://localhost:4566/restapis/$API_ID/prod/_user_request_/orders
```

**Check receipt in S3**:

```bash
aws s3 ls s3://order-receipts/receipts/ \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws s3 cp s3://order-receipts/receipts/{orderId}.json - \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

## Key Learning Points

### Service Integration

- API Gateway triggers Lambda (synchronous)
- Lambda writes to DynamoDB and SQS
- SQS triggers Lambda (async batch)
- Lambda invokes Step Functions
- Step Functions orchestrates multiple Lambdas
- Lambdas interact with DynamoDB and S3

### Error Handling

- API validation at entry point
- Retry logic in Step Functions
- Error states for different failure types
- Status tracking in DynamoDB

### Async Processing

- Immediate response to user (202 Accepted)
- Background processing via SQS
- Order status updates for tracking

### Data Flow

1. User submits order → API Gateway → Lambda
2. Order saved to DynamoDB (pending status)
3. Message sent to SQS
4. SQS triggers processor Lambda
5. Step Functions orchestrates validation, payment, receipt
6. Receipt stored in S3
7. Order status updated to completed

## Challenge Exercises

### 1. Add Inventory Deduction

Update inventory stock after successful order.

### 2. Implement Dead Letter Queue

Handle failed orders that couldn't be processed.

### 3. Add Customer Notifications

Send email/SMS notifications at each stage (use Pass state to simulate).

### 4. Implement Order Cancellation

Add API endpoint and workflow to cancel pending orders.

### 5. Add Analytics

Track order metrics (count, revenue, failure rate).

## Best Practices Demonstrated

### Architecture

- Separation of concerns (each Lambda has single responsibility)
- Async processing for better user experience
- Event-driven design
- Idempotent operations

### Scalability

- Stateless Lambda functions
- SQS for load leveling
- DynamoDB auto-scaling
- S3 for unlimited storage

### Reliability

- Retry mechanisms
- Error handling at each layer
- Status tracking
- Receipts as proof of transaction

### Cost Optimization

- Pay-per-use serverless model
- Efficient DynamoDB queries (no scans in hot path)
- S3 for cost-effective storage
- Step Functions for complex orchestration

## Cleanup

Clean up all resources using the AWS CLI commands from the earlier tasks.

## Real-World Extensions

### Production Enhancements

- Add authentication (Cognito)
- Implement rate limiting
- Add caching (ElastiCache/DAX)
- Enable CloudWatch monitoring
- Set up X-Ray tracing
- Implement CI/CD pipeline
- Add automated testing

### Monitoring

- CloudWatch dashboards
- Alarms for errors and latency
- Step Functions execution logs
- DynamoDB capacity metrics

### Security

- IAM least privilege
- Encrypt data at rest (S3, DynamoDB)
- VPC endpoints for private traffic
- WAF for API protection
- Secrets Manager for credentials

## Additional Resources

- [Serverless Application Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Event-Driven Architecture](https://aws.amazon.com/event-driven-architecture/)
