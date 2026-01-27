import time

def handler(event, context):
    print("Lambda D received:", event)
    time.sleep(0.5)
    event["value"] *= 2
    event["step"] = "D"
    return event
