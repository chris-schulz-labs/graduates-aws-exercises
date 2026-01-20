# Task 8: DynamoDB - NoSQL Database

## Objectives

Learn AWS DynamoDB fundamentals including table design, CRUD operations, indexes, and Lambda integration. Understand NoSQL data modeling and query patterns.

## Key Concepts

### What is DynamoDB?

DynamoDB is a fully managed NoSQL database service that provides fast and predictable performance with seamless scalability. Unlike relational databases (SQL), DynamoDB stores data in key-value and document formats.

### Core Concepts

**Tables and Items**
- **Table**: Collection of data (similar to a table in SQL)
- **Item**: Single data record (similar to a row in SQL)
- **Attribute**: Data element (similar to a column in SQL)

**Primary Keys**
- **Partition Key (PK)**: Required for every table; determines data distribution
- **Sort Key (SK)**: Optional; enables range queries and sorting
- **Composite Key**: Combination of partition key + sort key

**Key Types**
- Simple Primary Key: Partition key only
- Composite Primary Key: Partition key + sort key

### DynamoDB vs SQL Databases

| Feature | DynamoDB | SQL |
|---------|----------|-----|
| Data Model | Key-value, Document | Relational (tables) |
| Schema | Flexible (schema-less) | Fixed schema |
| Scaling | Automatic horizontal | Manual (vertical/horizontal) |
| Queries | Limited (key-based) | Flexible (SQL queries, joins) |
| Transactions | Limited ACID support | Full ACID support |
| Best For | High-throughput, low-latency | Complex queries, relationships |

### Secondary Indexes

**Global Secondary Index (GSI)**
- Alternative partition/sort keys
- Queries on non-primary-key attributes
- Eventually consistent
- Can be added after table creation

**Local Secondary Index (LSI)**
- Same partition key, different sort key
- Must be created with table
- Strongly consistent reads available
- Limited to 5 per table

### Query Patterns

**Query**: Efficient lookup using primary key or index
- Requires partition key
- Optionally filter by sort key
- Returns sorted results

**Scan**: Read entire table
- Slow and expensive
- Use only when necessary
- Can apply filters (but still scans all items)

### Consistency Models

- **Eventually Consistent Reads**: Default; maximum throughput
- **Strongly Consistent Reads**: Latest data; uses more capacity

## Architecture

In this exercise, you'll build a user management system with:
- User profiles stored in DynamoDB
- Lambda functions for CRUD operations
- GSI for email lookups
- Best practices for data modeling

## Prerequisites

- Completed Task 2 (Lambda Basics)
- LocalStack running with DynamoDB enabled
- AWS CLI configured with localstack profile

## Exercise Steps

### Step 1: Create DynamoDB Table

Create a Users table with email lookup capability.

```bash
aws dynamodb create-table \
    --table-name Users \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
        AttributeName=email,AttributeType=S \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
    --global-secondary-indexes \
        '[{
            "IndexName": "EmailIndex",
            "KeySchema": [{"AttributeName":"email","KeyType":"HASH"}],
            "Projection": {"ProjectionType":"ALL"},
            "ProvisionedThroughput": {"ReadCapacityUnits":5,"WriteCapacityUnits":5}
        }]' \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

Verify table creation:

```bash
aws dynamodb describe-table \
    --table-name Users \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

List tables:

```bash
aws dynamodb list-tables \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 2: CRUD Operations with AWS CLI

**Create (PutItem)**:

```bash
aws dynamodb put-item \
    --table-name Users \
    --item '{
        "userId": {"S": "user-001"},
        "email": {"S": "alice@example.com"},
        "name": {"S": "Alice Johnson"},
        "age": {"N": "28"},
        "role": {"S": "developer"}
    }' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

Add more users:

```bash
aws dynamodb put-item \
    --table-name Users \
    --item '{
        "userId": {"S": "user-002"},
        "email": {"S": "bob@example.com"},
        "name": {"S": "Bob Smith"},
        "age": {"N": "35"},
        "role": {"S": "manager"}
    }' \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws dynamodb put-item \
    --table-name Users \
    --item '{
        "userId": {"S": "user-003"},
        "email": {"S": "carol@example.com"},
        "name": {"S": "Carol Williams"},
        "age": {"N": "42"},
        "role": {"S": "architect"}
    }' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Read (GetItem)**:

```bash
aws dynamodb get-item \
    --table-name Users \
    --key '{"userId": {"S": "user-001"}}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Update (UpdateItem)**:

```bash
aws dynamodb update-item \
    --table-name Users \
    --key '{"userId": {"S": "user-001"}}' \
    --update-expression "SET age = :newAge, #r = :newRole" \
    --expression-attribute-names '{"#r": "role"}' \
    --expression-attribute-values '{":newAge": {"N": "29"}, ":newRole": {"S": "senior-developer"}}' \
    --return-values ALL_NEW \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Delete (DeleteItem)**:

```bash
aws dynamodb delete-item \
    --table-name Users \
    --key '{"userId": {"S": "user-003"}}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 3: Query Operations

**Query by primary key**:

```bash
aws dynamodb query \
    --table-name Users \
    --key-condition-expression "userId = :id" \
    --expression-attribute-values '{":id": {"S": "user-001"}}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Query using GSI (EmailIndex)**:

```bash
aws dynamodb query \
    --table-name Users \
    --index-name EmailIndex \
    --key-condition-expression "email = :email" \
    --expression-attribute-values '{":email": {"S": "bob@example.com"}}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Scan table**:

```bash
aws dynamodb scan \
    --table-name Users \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

**Scan with filter**:

```bash
aws dynamodb scan \
    --table-name Users \
    --filter-expression "age > :minAge" \
    --expression-attribute-values '{":minAge": {"N": "30"}}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 4: Lambda Function with DynamoDB

Create a Lambda function to manage users.

See [user_manager.py](user_manager.py) for the implementation. This function supports CREATE, READ, UPDATE, DELETE, LIST, and FIND_BY_EMAIL operations.

### Step 5: Create IAM Role for Lambda

**dynamodb-lambda-policy.json**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:000000000000:table/Users",
        "arn:aws:dynamodb:us-east-1:000000000000:table/Users/index/*"
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

Create role:

```bash
aws iam create-role \
    --role-name dynamodb-lambda-role \
    --assume-role-policy-document file://lambda-trust-policy.json \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws iam put-role-policy \
    --role-name dynamodb-lambda-role \
    --policy-name dynamodb-policy \
    --policy-document file://dynamodb-lambda-policy.json \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 6: Deploy Lambda Function

```bash
zip user-manager.zip user_manager.py

aws lambda create-function \
    --function-name user-manager \
    --runtime python3.9 \
    --role arn:aws:iam::000000000000:role/dynamodb-lambda-role \
    --handler user_manager.lambda_handler \
    --zip-file fileb://user-manager.zip \
    --endpoint-url http://localhost:4566 \
    --profile localstack
```

### Step 7: Test Lambda Function

**Create user**:

```bash
aws lambda invoke \
    --function-name user-manager \
    --payload '{"action": "CREATE", "data": {"userId": "user-101", "email": "test@example.com", "name": "Test User", "age": 25, "role": "tester"}}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack \
    response.json

cat response.json
```

**Read user**:

```bash
aws lambda invoke \
    --function-name user-manager \
    --payload '{"action": "READ", "userId": "user-101"}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack \
    response.json

cat response.json
```

**Update user**:

```bash
aws lambda invoke \
    --function-name user-manager \
    --payload '{"action": "UPDATE", "userId": "user-101", "updates": {"age": 26, "role": "senior-tester"}}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack \
    response.json

cat response.json
```

**Find by email**:

```bash
aws lambda invoke \
    --function-name user-manager \
    --payload '{"action": "FIND_BY_EMAIL", "email": "test@example.com"}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack \
    response.json

cat response.json
```

**List all users**:

```bash
aws lambda invoke \
    --function-name user-manager \
    --payload '{"action": "LIST"}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack \
    response.json

cat response.json
```

**Delete user**:

```bash
aws lambda invoke \
    --function-name user-manager \
    --payload '{"action": "DELETE", "userId": "user-101"}' \
    --endpoint-url http://localhost:4566 \
    --profile localstack \
    response.json

cat response.json
```

## Key Learning Points

### Primary Key Design

- Choose partition key with high cardinality (many unique values)
- Avoid "hot" partitions (keys with disproportionate traffic)
- Use composite keys when you need range queries

### When to Use GSI

- Query by non-primary-key attributes
- Support multiple access patterns
- Alternative sort orders

### Query vs Scan

- **Always prefer Query over Scan** when possible
- Query is efficient (uses indexes)
- Scan reads entire table (expensive and slow)
- Use Scan only for small tables or infrequent operations

### Capacity Planning

- **Provisioned mode**: Fixed capacity (cheaper for predictable workloads)
- **On-demand mode**: Pay per request (better for unpredictable workloads)
- LocalStack doesn't enforce capacity limits

### Attribute Naming

- Use camelCase or snake_case consistently
- Avoid reserved words (use ExpressionAttributeNames)
- Keep attribute names short (reduces storage cost)

## Challenge Exercises

### 1. Add LSI for Sorting

Create a Local Secondary Index to sort users by creation date within the same userId.

### 2. Batch Operations

Implement BatchWriteItem and BatchGetItem in the Lambda function.

### 3. Conditional Writes

Add conditional updates (e.g., only update if age is greater than current value).

### 4. TTL (Time To Live)

Add a TTL attribute to automatically delete expired items.

### 5. Transactions

Implement a multi-item transaction using TransactWriteItems.

## Best Practices

### Data Modeling

- Design tables around access patterns (not entities)
- Denormalize data (avoid joins)
- Use single-table design for related data
- Leverage composite keys and GSIs

### Performance

- Use batch operations for multiple items
- Implement pagination for large result sets
- Cache frequently accessed data
- Use eventually consistent reads when possible

### Cost Optimization

- Use on-demand pricing for variable workloads
- Delete unused GSIs
- Compress large attributes
- Set appropriate TTL to auto-delete old data

### Security

- Use IAM for access control
- Encrypt sensitive data at rest
- Enable point-in-time recovery
- Use VPC endpoints for private access

## Cleanup

```bash
aws lambda delete-function \
    --function-name user-manager \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws dynamodb delete-table \
    --table-name Users \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws iam delete-role-policy \
    --role-name dynamodb-lambda-role \
    --policy-name dynamodb-policy \
    --endpoint-url http://localhost:4566 \
    --profile localstack

aws iam delete-role \
    --role-name dynamodb-lambda-role \
    --endpoint-url http://localhost:4566 \
    --profile localstack

rm -f user-manager.zip response.json
```

## Real AWS Considerations

### Scaling

- DynamoDB auto-scales based on traffic
- No downtime for scaling operations
- Global Tables for multi-region replication

### Backup and Recovery

- Point-in-time recovery (PITR) for last 35 days
- On-demand backups for long-term retention
- Export to S3 for analytics

### Monitoring

- CloudWatch metrics (throttling, latency, capacity)
- DynamoDB Streams for change data capture
- Contributor Insights for access patterns

### Cost Management

- Reserved capacity for predictable workloads
- DynamoDB Accelerator (DAX) for caching
- Archive old data to S3 (cheaper storage)

## Additional Resources

- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/latest/developerguide/)
- [Best Practices for DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [DynamoDB Data Modeling](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-modeling-nosql.html)
- [LocalStack DynamoDB Documentation](https://docs.localstack.cloud/user-guide/aws/dynamodb/)
