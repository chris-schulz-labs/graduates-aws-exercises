import json
import boto3
import uuid
import os
from datetime import datetime

endpoint_url = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")
s3 = boto3.client("s3", endpoint_url=endpoint_url)
BUCKET = "api-data-store"


def handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    http_method = event["httpMethod"]
    path = event["path"]
    path_parameters = event.get("pathParameters") or {}
    body = event.get("body")

    if http_method == "GET" and path == "/items":
        return list_items()
    elif http_method == "GET" and path.startswith("/items/"):
        item_id = path_parameters.get("id")
        return get_item(item_id)
    elif http_method == "POST" and path == "/items":
        return create_item(body)
    elif http_method == "DELETE" and path.startswith("/items/"):
        item_id = path_parameters.get("id")
        return delete_item(item_id)
    else:
        return response(404, {"error": "Not found"})


def list_items():
    try:
        result = s3.list_objects_v2(Bucket=BUCKET, Prefix="items/")
        items = []

        if "Contents" in result:
            for obj in result["Contents"]:
                key = obj["Key"]
                if key != "items/":
                    item_data = s3.get_object(Bucket=BUCKET, Key=key)
                    item = json.loads(item_data["Body"].read().decode("utf-8"))
                    items.append(item)

        return response(200, {"items": items, "count": len(items)})
    except Exception as e:
        return response(500, {"error": str(e)})


def get_item(item_id):
    if not item_id:
        return response(400, {"error": "Missing item ID"})

    try:
        key = f"items/{item_id}.json"
        result = s3.get_object(Bucket=BUCKET, Key=key)
        item = json.loads(result["Body"].read().decode("utf-8"))
        return response(200, item)
    except s3.exceptions.NoSuchKey:
        return response(404, {"error": "Item not found"})
    except Exception as e:
        return response(500, {"error": str(e)})


def create_item(body):
    if not body:
        return response(400, {"error": "Missing request body"})

    try:
        data = json.loads(body)
        item_id = str(uuid.uuid4())

        item = {
            "id": item_id,
            "name": data.get("name", "Unnamed"),
            "description": data.get("description", ""),
            "created_at": datetime.utcnow().isoformat(),
        }

        key = f"items/{item_id}.json"
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps(item),
            ContentType="application/json",
        )

        return response(201, item)
    except json.JSONDecodeError:
        return response(400, {"error": "Invalid JSON"})
    except Exception as e:
        return response(500, {"error": str(e)})


def delete_item(item_id):
    if not item_id:
        return response(400, {"error": "Missing item ID"})

    try:
        key = f"items/{item_id}.json"
        s3.head_object(Bucket=BUCKET, Key=key)
        s3.delete_object(Bucket=BUCKET, Key=key)
        return response(200, {"message": "Item deleted", "id": item_id})
    except s3.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "404":
            return response(404, {"error": "Item not found"})
        return response(500, {"error": str(e)})
    except Exception as e:
        return response(500, {"error": str(e)})


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
