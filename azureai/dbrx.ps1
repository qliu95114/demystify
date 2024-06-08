Function Invoke-DBRXCompletion {
    Param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$token=8000,
        [single]$temperature=0.7
    )

    $url = $env:DATABRICKS_WORKSPACE_URL + "/serving-endpoints/databricks-mixtral-8x7b-instruct/invocations"
    Write-UTCLog "AI Endpoints: $($url)" "DarkCyan"

    $headers = @{
        "Authorization" = "Basic $($env:DATABRICKS_TOKEN)"
    }

    $promptPayload = [PSCustomObject]@{
        "content" = $Prompt
        "role"    = "system"
    }

    $messagePayload = [PSCustomObject]@{
        "content" = $Message
        "role"    = "user"
    }

    $payload = [PSCustomObject]@{
        "model"             = $DeploymentName
        "max_tokens"        = 8000
        "messages"          = @($promptPayload, $messagePayload)
        "stream"            = $false
        "temperature"       = $temperature
        "top_p"             = 0.95
    }

    $body = ConvertTo-Json -InputObject $payload -Compress 
    if ($debug) { Write-UTCLog "Payload: $($body)" "DarkCyan" }
    #$body = $body -creplace '\P{IsBasicLatin}'  # this leaves only ASCII characters does not accept the chinese characters
    $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json;charset=utf-8' 
    return $result
}
