import time

def handler(event, context):
    print("Lambda B received:", event)
    time.sleep(0.5)
    event["value"] += 1
    event["step"] = "B"
    return event
