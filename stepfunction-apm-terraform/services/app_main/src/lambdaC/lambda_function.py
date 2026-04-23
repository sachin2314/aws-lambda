# lambdaC/lambda_function.py
import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

table_name = os.getenv("TABLE_NAME", "DemoTable")
table = dynamodb.Table(table_name)

def handler(event, context):
    print("LambdaC started with event:", json.dumps(event))

    key = event.get("key")
    if not key:
        raise ValueError("Missing 'key' in input from LambdaB")

    resp = table.get_item(Key={"pk": key, "sk": event.get("sk", "unknown")})
    item = resp.get("Item", {})

    buckets = s3.list_buckets()
    bucket_names = [b["Name"] for b in buckets.get("Buckets", [])]

    result = {
        "item": item,
        "buckets": bucket_names,
        "source": "LambdaC"
    }

    print("LambdaC result:", json.dumps(result))
    return result
