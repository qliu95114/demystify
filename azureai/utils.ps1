#logging
Function Write-UTCLog ([string]$message, [string]$color = "white") {
    $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    $logstamp = "[" + $logdate + "]," + $message
    Write-Host $logstamp -ForegroundColor $color
}

# Powershell Function Send-AIEvent , 2024-04-12
Function Send-AIEvent{
    param (
                [Guid]$piKey,
                [String]$pEventName,
                [Hashtable]$pCustomProperties,
                [string]$logpath=$env:TEMP
    )
        $appInsightsEndpoint = "https://dc.services.visualstudio.com/v2/track"        
        
        if ([string]::IsNullOrEmpty($env:USERNAME)) {$uname=($env:USERPROFILE).split('\')[2]} else {$uname=$env:USERNAME}
        if ([string]::IsNullOrEmpty($env:USERDOMAIN)) {$domainname=$env:USERDOMAIN_ROAMINGPROFILE} else {$domainname=$env:USERDOMAIN}
            
        $body = (@{
                name = "Microsoft.ApplicationInsights.$iKey.Event"
                time = [DateTime]::UtcNow.ToString("o")
                iKey = $piKey
                tags = @{
                    "ai.user.id" = $uname
                    "ai.user.authUserId" = "$($domainname)\$($uname)"
                    "ai.cloud.roleInstance" = $env:COMPUTERNAME
                    "ai.device.osVersion" = [System.Environment]::OSVersion.VersionString
                    "ai.device.model"= (Get-CimInstance CIM_ComputerSystem).Model

          }
            "data" = @{
                    baseType = "EventData"
                    baseData = @{
                        ver = "2"
                        name = $pEventName
                        properties = ($pCustomProperties | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
                    }
                }
            }) | ConvertTo-Json -Depth 10 -Compress
    
        $temp = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"

        $attempt=1
        do {
            try {
                Invoke-WebRequest -Method POST -Uri $appInsightsEndpoint -Headers @{"Content-Type"="application/x-json-stream"} -Body $body -TimeoutSec 3 -UseBasicParsing| Out-Null 
                return    
            }
            catch {
                #Write-UTCLog "Send-AIEvent Failure: $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message)" -color "red"
                # determine if exception code < 400 and >= 500, or code is 429, we will retry
                $PreciseTimeStamp=((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")                
                if (($_.Exception.Response.StatusCode.value__ -lt 400 -or $_.Exception.Response.StatusCode.value__ -ge 500) -or ($_.Exception.Response.StatusCode.value__ -eq 429))
                {
                    #retry total 3 times, if failed, add message to aimessage.log and return $null
                    if ($attempt -ge 4)
                    {
                        Write-Output "retry 3 failure..." 
                        $sendaimessage =$PreciseTimeStamp+", Max retry attemps 3 reached, message lost"
                        $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                        return $null
                    }
                    Write-Output "Send-AIEvent Attempt($($attempt)): send aievent failure, retry" 
                    $sendaimessage =$PreciseTimeStamp+", Attempt($($attempt)) , $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message), retry..."
                    $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                    Start-Sleep -Seconds 1
                }
                else {
                    # unretrable error add message to aimessage.log and return $null
                    Write-UTCLog "Send-AIEvent unretrable error, message lost, $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message)" -color "red"
                    $sendaimessage=$PreciseTimeStamp+"Send-AIEvent unretrable error, message lost, $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message)"
                    $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                    return $null
                }
            }
            $attempt++
        } until ($success)
        $ProgressPreference = $temp
}
