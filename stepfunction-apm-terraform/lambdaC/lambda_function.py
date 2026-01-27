import time

def handler(event, context):
    print("Lambda C received:", event)
    time.sleep(0.5)
    event["value"] += 1
    event["step"] = "C"
    event["message"] = "Passing data to Step Function 2"
    return event
