#logging
Function Write-UTCLog ([string]$message, [string]$color = "white") {
    $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    $logstamp = "[" + $logdate + "]," + $message
    Write-Host $logstamp -ForegroundColor $color
}

# Powershell Function Send-AIEvent , 2023-08-12 , fix bug in retry logic
Function Send-AIEvent {
    param (
        [Guid]$piKey,
        [String]$pEventName,
        [Hashtable]$pCustomProperties,
        [string]$logpath = $env:temp
    )
    $appInsightsEndpoint = "https://dc.services.visualstudio.com/v2/track"

    if ([string]::IsNullOrEmpty($env:USERNAME)) { $uname = ($env:USERPROFILE).split('\')[2] } else { $uname = $env:USERNAME }
    if ([string]::IsNullOrEmpty($env:USERDOMAIN)) { $domainname = $env:USERDOMAIN_ROAMINGPROFILE } else { $domainname = $env:USERDOMAIN }
            
    $body = (@{
            name   = "Microsoft.ApplicationInsights.$iKey.Event"
            time   = [DateTime]::UtcNow.ToString("o")
            iKey   = $piKey
            tags   = @{
                "ai.user.id"            = $uname
                "ai.user.authUserId"    = "$($domainname)\$($uname)"
                "ai.cloud.roleInstance" = $env:COMPUTERNAME
                "ai.device.osVersion"   = [System.Environment]::OSVersion.VersionString
                "ai.device.model"       = (Get-CimInstance CIM_ComputerSystem).Model

            }
            "data" = @{
                baseType = "EventData"
                baseData = @{
                    ver        = "2"
                    name       = $pEventName
                    properties = ($pCustomProperties | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
                }
            }
        }) | ConvertTo-Json -Depth 10 -Compress
    
    $temp = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"

    $attempt = 1
    do {
        try {
            Invoke-WebRequest -Method POST -Uri $appInsightsEndpoint -Headers @{"Content-Type" = "application/x-json-stream" } -Body $body -TimeoutSec 3 -UseBasicParsing | Out-Null 
            return    
        }
        catch {
            $PreciseTimeStamp = (get-date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
            if ($attempt -ge 4) {
                Write-Output "retry 3 failure..." 
                $sendaimessage = $PreciseTimeStamp + ",Fail to send AI message after 3 attemps, message lost"
                $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                return $null
            }
            Write-Output "Attempt($($attempt)): send aievent failure, retry" 
            $sendaimessage = $PreciseTimeStamp + ", Attempt($($attempt)) , wait 1 second, resend AI message"
            $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
            Start-Sleep -Seconds 1
        }
        $attempt++
    } until ($success)
    $ProgressPreference = $temp
}

## Invoke-AzureAI-GPT
Function Invoke-ChartGPTCompletion {
    Param(
        [Parameter(Mandatory = $true)][string]$endpoint,
        [Parameter(Mandatory = $true)][string]$AccessKey,
        [Parameter(Mandatory = $true)][string]$DeploymentName,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $url = "$($endpoint)openai/deployments/$DeploymentName/chat/completions?api-version=2023-03-15-preview"
    if ($debug) { Write-UTCLog "AI Endpoints: $($url)" "DarkCyan" }

    $headers = @{
        "api-key" = $AccessKey
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
        "frequency_penalty" = 0
        "max_tokens"        = 20000
        "messages"          = @($promptPayload, $messagePayload)
        "presence_penalty"  = 0
        "stream"            = $false
        "temperature"       = 0.7
        "top_p"             = 0.95
    }

    # return $payload
    $body = ConvertTo-Json -InputObject $payload -Compress 
    
    if ($debug) { Write-UTCLog "Payload: $($body)" "DarkCyan" }

    #$body = $body -creplace '\P{IsBasicLatin}'  # this leaves only ASCII characters does not accept the chinese characters
    $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json;charset=utf-8' 
    return $result;
}