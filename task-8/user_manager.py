import json
import os
import boto3
from datetime import datetime

endpoint_url = os.environ.get('AWS_ENDPOINT_URL', 'http://localhost:4566')
dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)
table = dynamodb.Table('Users')

def lambda_handler(event, context):
    """
    User management Lambda function.
    Supports: CREATE, READ, UPDATE, DELETE, LIST operations
    """

    action = event.get('action')

    try:
        if action == 'CREATE':
            return create_user(event)
        elif action == 'READ':
            return read_user(event)
        elif action == 'UPDATE':
            return update_user(event)
        elif action == 'DELETE':
            return delete_user(event)
        elif action == 'LIST':
            return list_users(event)
        elif action == 'FIND_BY_EMAIL':
            return find_by_email(event)
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid action'})
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def create_user(event):
    """Create a new user."""
    data = event.get('data', {})

    item = {
        'userId': data['userId'],
        'email': data['email'],
        'name': data['name'],
        'createdAt': datetime.utcnow().isoformat()
    }

    if 'age' in data:
        item['age'] = int(data['age'])
    if 'role' in data:
        item['role'] = data['role']

    table.put_item(Item=item)

    return {
        'statusCode': 201,
        'body': json.dumps({
            'message': 'User created',
            'user': item
        })
    }

def read_user(event):
    """Get user by ID."""
    user_id = event.get('userId')

    response = table.get_item(Key={'userId': user_id})

    if 'Item' not in response:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'User not found'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps(response['Item'], default=str)
    }

def update_user(event):
    """Update user attributes."""
    user_id = event.get('userId')
    updates = event.get('updates', {})

    update_expr = "SET "
    expr_values = {}
    expr_names = {}

    for i, (key, value) in enumerate(updates.items()):
        attr_name = f"#attr{i}"
        attr_value = f":val{i}"

        if i > 0:
            update_expr += ", "

        update_expr += f"{attr_name} = {attr_value}"
        expr_names[attr_name] = key
        expr_values[attr_value] = value

    response = table.update_item(
        Key={'userId': user_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_names,
        ExpressionAttributeValues=expr_values,
        ReturnValues='ALL_NEW'
    )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'User updated',
            'user': response['Attributes']
        }, default=str)
    }

def delete_user(event):
    """Delete user by ID."""
    user_id = event.get('userId')

    table.delete_item(Key={'userId': user_id})

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'User deleted'})
    }

def list_users(event):
    """List all users (scan operation)."""
    response = table.scan()

    return {
        'statusCode': 200,
        'body': json.dumps({
            'count': response['Count'],
            'users': response['Items']
        }, default=str)
    }

def find_by_email(event):
    """Find user by email using GSI."""
    email = event.get('email')

    response = table.query(
        IndexName='EmailIndex',
        KeyConditionExpression='email = :email',
        ExpressionAttributeValues={':email': email}
    )

    if response['Count'] == 0:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'User not found'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps(response['Items'][0], default=str)
    }
