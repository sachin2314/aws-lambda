import time

def handler(event, context):
    print("Lambda A received:", event)
    time.sleep(0.5)
    return {
        "step": "A",
        "message": "Hello from Lambda A",
        "value": 1
    }
