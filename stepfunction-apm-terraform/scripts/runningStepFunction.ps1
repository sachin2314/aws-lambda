# $input_var = '{ \"value\": 4}'


# for ($i=1; $i -le 10; $i++) {
#   aws stepfunctions start-execution `
#     --state-machine-arn arn:aws:states:eu-west-1:856364870958:stateMachine:StepFunction1 `
#     --input "{ \"value\": $i }"
# }

for ($i = 1; $i -le 2; $i++) {
    $payload = @{ value = $i } | ConvertTo-Json -Compress
    $quoted = '"' + $payload.Replace('"', '\"') + '"'
    aws stepfunctions start-execution `
        --state-machine-arn arn:aws:states:us-east-1:856364870958:stateMachine:StepFunction1 `
        --input $quoted
}


# Start StepFunction1 and capture the output
# $execution = aws stepfunctions start-execution `
#   --state-machine-arn arn:aws:states:eu-west-1:856364870958:stateMachine:StepFunction1 `
#   --input $input_var

# Write-Host "Started execution:"
# Write-Host $execution.executionArn

# Wait a few seconds for the execution to begin
# Start-Sleep -Seconds 3

# Fetch execution history using the REAL execution ARN
# aws stepfunctions get-execution-history `
#   --execution-arn $execution.executionArn `
#   --max-results 100
