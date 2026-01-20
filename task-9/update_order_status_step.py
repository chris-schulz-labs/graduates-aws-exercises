import json
import os
import boto3
from decimal import Decimal

endpoint_url = os.environ.get("AWS_ENDPOINT_URL", "http://localhost:4566")
dynamodb = boto3.resource("dynamodb", endpoint_url=endpoint_url)
orders_table = dynamodb.Table("Orders")


def lambda_handler(event, context):
    order_id = event["orderId"]

    orders_table.update_item(
        Key={"orderId": order_id},
        UpdateExpression="SET #status = :status, receiptUrl = :receiptUrl, totalPrice = :totalPrice",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": "completed",
            ":receiptUrl": event["receipt"]["receiptUrl"],
            ":totalPrice": Decimal(str(event["validation"]["totalPrice"])),
        },
    )

    return {"status": "completed", "message": "Order processed successfully"}
