import time

def handler(event, context):
    print("Lambda D received:", event)
    time.sleep(0.5)
    number = event["value"]["value"] # extract the inner number 
    number *= 2

    event["step"] = "D" 
    event["value"]= number 
    event["message"] = "Processed by Lambda D"

    return event
