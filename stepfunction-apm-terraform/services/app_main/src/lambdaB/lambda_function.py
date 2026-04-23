# lambdaB/lambda_function.py
import json
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table_name = os.getenv("TABLE_NAME", "DemoTable")
table = dynamodb.Table(table_name)

def handler(event, context):
    print("LambdaB started with event:", json.dumps(event))

    value = event.get("value")
    config = event.get("config")

    item = {
        "pk": f"value#{value}",
        "sk": datetime.utcnow().isoformat(),
        "config": config,
        "source": "LambdaB"
    }

    table.put_item(Item=item)

    result = {
        "status": "written",
        "key": item["pk"],
        "source": "LambdaB"
    }

    print("LambdaB result:", json.dumps(result))
    return result
