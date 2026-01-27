import time

def handler(event, context):
    print("Lambda E received:", event)
    time.sleep(0.5)
    event["value"] += 10
    event["step"] = "E"
    event["final"] = True
    return event
