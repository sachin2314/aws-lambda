# lambdaE/lambda_function.py
import json
import time

def handler(event, context):
    print("LambdaE started with event:", json.dumps(event))

    # Simulate some final processing
    time.sleep(0.2)

    result = {
        "status": "completed",
        "input": event,
        "source": "LambdaE"
    }

    print("LambdaE final result:", json.dumps(result))
    return result
