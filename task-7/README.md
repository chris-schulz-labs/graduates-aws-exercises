# Task 7: Step Functions - Workflow Orchestration

## Objectives

Learn how to orchestrate multiple AWS services using Step Functions state machines. This exercise introduces workflow coordination, error handling, parallel execution, and retry logic.

## Key Concepts

### What is AWS Step Functions?

Step Functions is a serverless orchestration service that lets you coordinate multiple AWS services into serverless workflows. Instead of managing complex logic within individual Lambda functions, you define workflows as state machines using Amazon States Language (ASL).

### State Machine Components

- **States**: Individual steps in your workflow (Task, Choice, Parallel, Wait, etc.)
- **Transitions**: Connections between states that define workflow flow
- **Input/Output Processing**: Data transformation between states
- **Error Handling**: Retry and catch mechanisms for fault tolerance

### State Types

- **Task**: Executes work (Lambda function, API call, etc.)
- **Choice**: Branching logic based on input
- **Parallel**: Execute multiple branches simultaneously
- **Wait**: Delay for a specified time
- **Pass**: Transform input to output without doing work
- **Succeed/Fail**: Terminal states

### Why Use Step Functions?

- **Visual Workflows**: See your application logic as a diagram
- **Built-in Error Handling**: Automatic retries and error catching
- **State Management**: No need to manage workflow state in databases
- **Service Integration**: Native integration with 200+ AWS services
- **Auditability**: Complete execution history and logging

## Architecture

In this exercise, you'll build an order processing workflow:

```
Start
  ↓
Validate Order (Lambda)
  ↓
Check Inventory (Lambda)
  ↓
[Choice: Inventory Available?]
  ↓ Yes                    ↓ No
Process Payment        Send Out-of-Stock Alert
  ↓                         ↓
Ship Order              Update Backorder
  ↓                         ↓
Success                   Success
```

## Prerequisites

- Completed Task 2 (Lambda Basics)
- LocalStack running with Step Functions enabled
- AWS CLI configured with localstack profile

## Exercise Steps

### Step 1: Create Lambda Functions for Workflow Steps

We'll create three Lambda functions that the workflow will orchestrate.

See the implementation files:
- [validate_order.py](validate_order.py) - Validates order data
- [check_inventory.py](check_inventory.py) - Checks inventory availability (simulated)
- [process_payment.py](process_payment.py) - Processes payment (simulated)

Create and deploy these functions:

```bash
# Create validate-order function
zip validate-function.zip validate_order.py
aws lambda create-function \
    --function-name validate-order \
    --runtime python3.9 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler validate_order.lambda_handler \
    --zip-file fileb://validate-function.zip \
    --endpoint-url http://localhost:4566 \
    --profile localstack

# Create check-inventory function
zip inventory-function.zip check_inventory.py
aws lambda create-function \
    --function-name check-inventory \
    --runtime python3.9 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler check_inventory.lambda_handler \
    --zip-file fileb://inventory-function.zip \
    --endpoint-url http://localhost:4566 \
    --profile localstack

# Create process-payment function
zip payment-function.zip process_payment.py
aws lambda create-function \
    --function-name process-payment \
    --runtime python3.9 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler process_payment.lambda_handler \
    --zip-file fileb://payment-function.zip \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 2: Create IAM Role for Step Functions

Step Functions needs permission to invoke Lambda functions.

**stepfunctions-role-policy.json**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "*"
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

**stepfunctions-trust-policy.json**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

Create the role:

```bash
aws iam create-role \
    --role-name stepfunctions-role \
    --assume-role-policy-document file://stepfunctions-trust-policy.json \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws iam put-role-policy \
    --role-name stepfunctions-role \
    --policy-name stepfunctions-policy \
    --policy-document file://stepfunctions-role-policy.json \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 3: Define the State Machine

Create the workflow definition using Amazon States Language (ASL).

**order-workflow.json**:
```json
{
  "Comment": "Order processing workflow with validation, inventory check, and payment",
  "StartAt": "ValidateOrder",
  "States": {
    "ValidateOrder": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:validate-order",
      "ResultPath": "$.validation",
      "Next": "CheckValidation"
    },
    "CheckValidation": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.validation.valid",
          "BooleanEquals": true,
          "Next": "CheckInventory"
        }
      ],
      "Default": "ValidationFailed"
    },
    "ValidationFailed": {
      "Type": "Fail",
      "Error": "ValidationError",
      "Cause": "Order validation failed"
    },
    "CheckInventory": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:check-inventory",
      "ResultPath": "$.inventory",
      "Next": "IsInventoryAvailable"
    },
    "IsInventoryAvailable": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.inventory.inventoryAvailable",
          "BooleanEquals": true,
          "Next": "ProcessPayment"
        }
      ],
      "Default": "OutOfStock"
    },
    "ProcessPayment": {
      "Type": "Task",
      "Resource": "arn:aws:lambda:us-east-1:000000000000:function:process-payment",
      "ResultPath": "$.payment",
      "Retry": [
        {
          "ErrorEquals": ["States.TaskFailed"],
          "IntervalSeconds": 2,
          "MaxAttempts": 3,
          "BackoffRate": 2.0
        }
      ],
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "PaymentFailed",
          "ResultPath": "$.error"
        }
      ],
      "Next": "OrderCompleted"
    },
    "PaymentFailed": {
      "Type": "Pass",
      "Result": {
        "status": "payment_failed",
        "message": "Payment processing failed after retries"
      },
      "ResultPath": "$.result",
      "Next": "Failure"
    },
    "OutOfStock": {
      "Type": "Pass",
      "Result": {
        "status": "out_of_stock",
        "message": "Item currently unavailable"
      },
      "ResultPath": "$.result",
      "Next": "Failure"
    },
    "OrderCompleted": {
      "Type": "Pass",
      "Result": {
        "status": "completed",
        "message": "Order processed successfully"
      },
      "ResultPath": "$.result",
      "End": true
    },
    "Failure": {
      "Type": "Fail",
      "Error": "OrderProcessingError",
      "Cause": "Order could not be completed"
    }
  }
}
```

### Step 4: Create the State Machine

```bash
aws stepfunctions create-state-machine \
    --name order-processing-workflow \
    --definition file://order-workflow.json \
    --role-arn arn:aws:iam::000000000000:role/stepfunctions-role \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 5: Execute the Workflow

Start an execution with sample order data:

```bash
aws stepfunctions start-execution \
    --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:order-processing-workflow \
    --name execution-1 \
    --input '{"orderId": "ORDER-001", "customerId": "CUST-123", "amount": 99.99}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 6: Monitor Execution

Check execution status:

```bash
aws stepfunctions describe-execution \
    --execution-arn arn:aws:states:us-east-1:000000000000:execution:order-processing-workflow:execution-1 \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

Get execution history:

```bash
aws stepfunctions get-execution-history \
    --execution-arn arn:aws:states:us-east-1:000000000000:execution:order-processing-workflow:execution-1 \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

List all executions:

```bash
aws stepfunctions list-executions \
    --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:order-processing-workflow \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

## Key Learning Points

### Error Handling

The workflow demonstrates two error handling mechanisms:

1. **Retry**: The ProcessPayment state retries up to 3 times with exponential backoff
2. **Catch**: If all retries fail, the error is caught and routed to PaymentFailed state

### Choice States

Two Choice states demonstrate branching logic:
- CheckValidation: Routes based on validation result
- IsInventoryAvailable: Routes based on inventory status

### ResultPath

Each Task state uses `ResultPath` to preserve the original input while adding new data:
- Original input is preserved
- Task output is added at the specified path
- Next state receives combined data

### Pass States

Pass states transform data without calling external services:
- Useful for adding metadata
- Minimal cost (no Lambda invocation)
- Can reshape data structure

## Challenge Exercises

### 1. Add Parallel Processing

Modify the workflow to check inventory and validate payment method in parallel.

### 2. Add Wait State

Add a Wait state to simulate a processing delay (e.g., 5 seconds after payment).

### 3. Implement Notifications

Add an SNS notification state to send order confirmation emails (use Pass state to simulate).

### 4. Add Map State

Create a workflow that processes multiple order items using a Map state.

### 5. Error Metrics

Track how many executions fail at each stage by examining execution history.

## Testing Different Scenarios

Test various inputs to see different workflow paths:

**Valid order (should succeed most times)**:
```json
{
  "orderId": "ORDER-001",
  "customerId": "CUST-123",
  "amount": 99.99
}
```

**Invalid order (missing fields)**:
```json
{
  "orderId": "ORDER-002",
  "amount": 50.00
}
```

**Invalid amount**:
```json
{
  "orderId": "ORDER-003",
  "customerId": "CUST-124",
  "amount": -10.00
}
```

## Cleanup
```bash
# Delete state machine
aws stepfunctions delete-state-machine \
    --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:order-processing-workflow \
    --endpoint-url http://localhost:4566 \
    --profile localstack

# Delete Lambda functions
aws lambda delete-function --function-name validate-order --endpoint-url http://localhost:4566 --profile localstack
aws lambda delete-function --function-name check-inventory --endpoint-url http://localhost:4566 --profile localstack
aws lambda delete-function --function-name process-payment --endpoint-url http://localhost:4566 --profile localstack

# Delete IAM role
aws iam delete-role-policy --role-name stepfunctions-role --policy-name stepfunctions-policy --endpoint-url http://localhost:4566 --profile localstack
aws iam delete-role --role-name stepfunctions-role --endpoint-url http://localhost:4566 --profile localstack
```

## Real AWS Considerations

### Cost Optimization

- Step Functions charges per state transition
- Use Pass states instead of Lambda for simple transformations
- Batch multiple items using Map state instead of separate executions

### Limits

- Standard Workflows: 1 year maximum execution time
- Express Workflows: 5 minutes maximum (lower cost, higher throughput)
- 25,000 events per execution (history limit)

### Best Practices

- Use Express Workflows for high-volume, short-duration workloads
- Implement idempotency in Lambda functions
- Use execution names to prevent duplicate processing
- Monitor with CloudWatch metrics and alarms
- Use tags for cost allocation and organization

### Security

- Follow least privilege for Step Functions role
- Use VPC endpoints for private executions
- Encrypt sensitive data in state machine definitions
- Use AWS Secrets Manager for credentials

## Additional Resources

- [AWS Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/latest/dg/)
- [Amazon States Language Specification](https://states-language.net/spec.html)
- [Step Functions Best Practices](https://docs.aws.amazon.com/step-functions/latest/dg/best-practices.html)
- [LocalStack Step Functions Documentation](https://docs.localstack.cloud/user-guide/aws/stepfunctions/)
