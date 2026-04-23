import json

def handler(event, context):
    print("LambdaE started with event:", json.dumps(event))

    # Extract nested value
    value = event.get("input", {}).get("value")

    if value is None:
        raise KeyError("Expected event['input']['value'] but it was missing")

    # Do something with the value
    result = {
        "status": "finalized",
        "value": value,
        "source": "LambdaE"
    }

    print("LambdaE result:", json.dumps(result))
    return result
