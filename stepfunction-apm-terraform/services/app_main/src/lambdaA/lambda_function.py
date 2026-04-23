# lambdaA/lambda_function.py
import json
import os
import boto3

ssm = boto3.client("ssm")

def handler(event, context):
    print("LambdaA started with event:", json.dumps(event))

    value = event.get("value")
    if value is None:
        raise ValueError("Missing 'value' in input")

    param_name = os.getenv("CONFIG_PARAM_NAME", "/demo/app/config")
    resp = ssm.get_parameter(Name=param_name, WithDecryption=True)
    config_value = resp["Parameter"]["Value"]

    result = {
        "value": value,
        "config": config_value,
        "source": "LambdaA"
    }

    print("LambdaA result:", json.dumps(result))
    return result
