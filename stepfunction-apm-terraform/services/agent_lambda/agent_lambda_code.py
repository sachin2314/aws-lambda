import json
import boto3
import os
from datetime import datetime, timedelta, timezone

cloudwatch = boto3.client("cloudwatch")
logs = boto3.client("logs")
lambda_client = boto3.client("lambda")

DIAG_WINDOW_MINUTES = int(os.getenv("DIAG_WINDOW_MINUTES", "15"))
LOG_WINDOW_MINUTES = int(os.getenv("LOG_WINDOW_MINUTES", "15"))


def handler(event, context):
    print("Received event:", json.dumps(event))

    for record in event.get("Records", []):
        message = json.loads(record["Sns"]["Message"])
        process_alarm_message(message)

    return {"status": "ok"}


def process_alarm_message(message: dict):
    if message.get("NewStateValue") != "ALARM":
        print("Not an ALARM state, ignoring.")
        return

    alarm_name = message.get("AlarmName")
    trigger = message.get("Trigger", {})
    dimensions = trigger.get("Dimensions", [])

    function_name = None
    for d in dimensions:
        if d.get("name") == "FunctionName":
            function_name = d.get("value")
            break

    if not function_name:
        print(f"Could not determine function name from alarm {alarm_name}")
        return

    print(f"Investigating high memory for Lambda: {function_name}")

    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(minutes=DIAG_WINDOW_MINUTES)

    metrics = get_lambda_metrics(function_name, start_time, end_time)
    config = get_lambda_config(function_name)
    log_insights = get_lambda_logs(function_name, end_time)

    diagnosis = build_diagnosis(function_name, metrics, config, log_insights, start_time, end_time)

    print("=== LAMBDA MEMORY DIAGNOSIS ===")
    print(json.dumps(diagnosis, indent=2, default=str))


def get_lambda_metrics(function_name: str, start_time, end_time):
    def fetch(metric_name, stat="Average"):
        resp = cloudwatch.get_metric_statistics(
            Namespace="AWS/Lambda",
            MetricName=metric_name,
            Dimensions=[{"Name": "FunctionName", "Value": function_name}],
            StartTime=start_time,
            EndTime=end_time,
            Period=60,
            Statistics=[stat],
        )
        datapoints = sorted(resp.get("Datapoints", []), key=lambda x: x["Timestamp"])
        return datapoints

    return {
        "MaxMemoryUsed": fetch("MaxMemoryUsed", "Maximum"),
        "MemorySize": fetch("MemorySize", "Maximum"),
        "Duration": fetch("Duration", "Average"),
        "Invocations": fetch("Invocations", "Sum"),
        "Errors": fetch("Errors", "Sum"),
        "Throttles": fetch("Throttles", "Sum"),
    }


def get_lambda_config(function_name: str):
    resp = lambda_client.get_function_configuration(FunctionName=function_name)
    return {
        "FunctionName": resp.get("FunctionName"),
        "MemorySize": resp.get("MemorySize"),
        "Timeout": resp.get("Timeout"),
        "LastModified": resp.get("LastModified"),
        "Runtime": resp.get("Runtime"),
        "Handler": resp.get("Handler"),
        "VpcConfig": resp.get("VpcConfig"),
    }


def get_lambda_logs(function_name: str, end_time):
    log_group = f"/aws/lambda/{function_name}"
    start_time = int((end_time - timedelta(minutes=LOG_WINDOW_MINUTES)).timestamp() * 1000)
    end_ms = int(end_time.timestamp() * 1000)

    patterns = [
        "OutOfMemoryError",
        "Task timed out",
        "Process exited before completing request",
        "MemoryError",
        "Init Duration",
    ]

    findings = {p: [] for p in patterns}

    try:
        next_token = None
        while True:
            kwargs = {
                "logGroupName": log_group,
                "startTime": start_time,
                "endTime": end_ms,
                "limit": 1000,
            }
            if next_token:
                kwargs["nextToken"] = next_token

            resp = logs.filter_log_events(**kwargs)

            for event in resp.get("events", []):
                msg = event.get("message", "")
                ts = event.get("timestamp")
                for p in patterns:
                    if p in msg:
                        findings[p].append({"timestamp": ts, "message": msg[:500]})

            next_token = resp.get("nextToken")
            if not next_token:
                break

    except logs.exceptions.ResourceNotFoundException:
        print(f"No log group found for {log_group}")

    return findings


def build_diagnosis(function_name, metrics, config, log_insights, start_time, end_time):
    mem_points = metrics.get("MaxMemoryUsed", [])
    size_points = metrics.get("MemorySize", [])
    duration_points = metrics.get("Duration", [])
    invocation_points = metrics.get("Invocations", [])
    error_points = metrics.get("Errors", [])

    latest_mem = mem_points[-1]["Maximum"] if mem_points else None
    latest_size = size_points[-1]["Maximum"] if size_points else None
    mem_percent = None
    if latest_mem and latest_size:
        mem_percent = round(latest_mem / latest_size * 100, 2)

    total_invocations = sum(p["Sum"] for p in invocation_points) if invocation_points else 0
    total_errors = sum(p["Sum"] for p in error_points) if error_points else 0

    evidence = []

    if mem_percent is not None:
        evidence.append(f"Latest memory usage is {mem_percent}% of configured memory.")

    if total_invocations:
        evidence.append(f"Total invocations in window: {total_invocations}.")
    if total_errors:
        evidence.append(f"Total errors in window: {total_errors}.")

    if log_insights.get("OutOfMemoryError"):
        evidence.append("OutOfMemoryError detected in logs.")
    if log_insights.get("Task timed out"):
        evidence.append("Task timed out errors detected.")
    if log_insights.get("Process exited before completing request"):
        evidence.append("Process exited before completing request detected.")

    likely_cause = []
    recommendations = []

    if mem_percent and mem_percent >= 80:
        likely_cause.append("Function is close to or exceeding memory limits.")
        recommendations.append("Consider increasing memory size and monitoring again.")

    if log_insights.get("OutOfMemoryError"):
        likely_cause.append("Function is running out of memory during execution.")
        recommendations.append("Review object allocations and large in-memory structures.")
        recommendations.append("Stream large payloads instead of loading them fully.")

    if log_insights.get("Task timed out"):
        likely_cause.append("Function is timing out, possibly due to slow downstream calls or heavy processing.")
        recommendations.append("Increase timeout or optimize external calls / processing logic.")

    if not likely_cause:
        likely_cause.append("High memory usage detected but no clear error pattern in logs.")
        recommendations.append("Profile memory usage locally or with AWS Lambda Power Tuning.")
        recommendations.append("Review recent code changes and payload sizes.")

    summary = f"Lambda '{function_name}' shows high memory usage between {start_time} and {end_time}."

    return {
        "summary": summary,
        "function": function_name,
        "time_window": {
            "start": start_time,
            "end": end_time,
        },
        "config": config,
        "metrics_overview": {
            "latest_memory_bytes": latest_mem,
            "latest_memory_size_bytes": latest_size,
            "latest_memory_percent": mem_percent,
            "total_invocations": total_invocations,
            "total_errors": total_errors,
        },
        "log_findings": {k: len(v) for k, v in log_insights.items()},
        "evidence": evidence,
        "likely_root_cause": likely_cause,
        "recommendations": recommendations,
    }
