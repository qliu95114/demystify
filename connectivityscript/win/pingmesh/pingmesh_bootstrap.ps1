<#
.SYNOPSIS
Ping Mesh Boot Strip

.DESCRIPTION


.PARAMETER url

.PARAMETER configjson
Provide Logfile path and filename

.PARAMETER time
CURL timeout in seconds, default 3.  --connect-timeout  (default:15) 

.PARAMETER count 
Total execution of $url or $urlfile (Default: 10) , 0 - Forever

.PARAMETER deplay
Milliseconds, dely between each execution of $url, but there is no delay within in $urlfile (Default: 1000)

.PARAMETER aikey
GUID, Instrumentation Key used by Application Insight

.EXAMPLE
.\pingmesh_bootstrip.ps1 -delay 0 -url https://www.bing.com 

#>
Param(
	[string] $configjson, #this will be URL point to storage account with config.json
    [string] $sa, #storage account for log saving
    [string] $saaccess, #storage account access key
    [string] $aikey
)

function Write-UTCLog {
    Param([string]$MESSAGE, [string]$color = "gray")
    $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")
    $logstamp = "[" + $logdate + "]," + $MESSAGE
    Write-Host $logstamp -ForegroundColor $color
}


# Powershell Function Send-AIEvent , 2023-04-08
Function Send-AIEvent{
    param (
                [Guid]$piKey,
                [String]$pEventName,
                [Hashtable]$pCustomProperties
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
                $PreciseTimeStamp=($timeStart.ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
                if ($attempt -ge 4)
                {
                    Write-Output "retry 3 failure..." 
                    $sendaimessage =$PreciseTimeStamp+",Fail to send AI message after 3 attemps, message lost"
                    $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                    return $null
                }
                Write-Output "Attempt($($attempt)): send aievent failure, retry" 
                $sendaimessage =$PreciseTimeStamp+", Attempt($($attempt)) , wait 1 second, resend AI message"
                $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                Start-Sleep -Seconds 1
            }
            $attempt++
        } until ($success)
        $ProgressPreference = $temp
    }


# main program
# please add retry logic in case of download failed to download $configjson and send to $config

$retry_delay = 10

if (Test-path "c:\pingmesh_config.txt")
{
    $configjson=Get-Content "c:\pingmesh_config.txt"
}
else {
    $configjson="https://pingmeshdigitalnative.blob.core.windows.net/config/config.json"
}

while ($true) {
    try {
        $response = Invoke-WebRequest -Uri $configjson
        if ($response.StatusCode -ne 200) {
            throw "Received non-200 status code $($response.StatusCode)"
        }
        $config = $response.Content | ConvertFrom-Json
        Write-UTCLog "Download $($configjson) successfully"
        break  # exit loop if successful
    } catch {
        Write-UTCLog "Failed to download $($configjson): $($_.Exception.Message)"
        Write-UTCLog "Retrying in $($retry_delay) seconds..."
        Start-Sleep -Seconds $retry_delay
    }
}

$containerid=([xml](c:\windows\system32\curl "http://168.63.129.16/machine?comp=goalstate" -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A """")).GoalState.Container.ContainerId

#if $containerid is NULL or empty , then 00000000-0000-0000-0000-000000000000
if ([string]::IsNullOrEmpty($containerid)) {$containerid="00000000-0000-0000-0000-000000000000"}

# Prepare Azure File mount point for log saving..

# if $salog is not empty
<#if ($salog) {
    $storageAccountName = $salog
    $sharefolder = "log"
    $storageAccountKey = $saaccess
    New-PSDrive -Name O -PSProvider FileSystem -Root "\\$($sa).file.core.windows.net\log" -Credential $saaccess -Persist
    $logfile = "O:\$sharefolder\$logfile"
}#>

# loop config ip list
# json format  is 
<# {
    "env":"SHEIN",
    "timeout": 1,
    "delay": 1,
    "tcpping": "true",
    "tcpport": 445,
    "iplist":
    [
        {"ip":"10.10.10.1"},
        {"ip":"10.10.10.2"}
    ]
} #>

$env = $config.env
$timeout = $config.timeout
$delay = $config.delay
$logpath="d:\temp\$($env)"
if (Test-Path $logpath) {   } else  {   mkdir $logpath}

Write-UTCLog "Download Test-ICMP.ps1 from github!"

# downlaod test-icmp.ps1 from github
$url = "https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/win/Test-ICMP.ps1"
$outputPath = "$($env:temp)\test-icmp.ps1"
$maxRetries = 3
for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        Invoke-WebRequest $url -OutFile $outputPath
        break
    } catch {
        Write-Host "Download failed on attempt $i. Retrying..."
        Start-Sleep -Seconds 5
    }
}

# loop config ip list
foreach ($ip in $config.iplist) {
    # get machine ip address
    $ipaddr = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -eq "Ethernet"}).IPAddress
    # if matches then skip
    if ($ipaddr -eq $ip.ip) {
        Write-UTCLog "Skip $ipaddr"
        continue
    }
    else {
        # if when we have 20 threads tcp ping via PS and .NET core, DS1_v2 can barely handle 20 threads, so we need have a big machine to change to another way run ping 
        Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @("-NoProfile","-file","$($env:temp)\test-icmp.ps1","-IPAddress","$($ip.ip)","-intervalinMS","$($delay)","-timeout","$($timeout)","-forever","-logpath","$($logpath)","-containerid","$($ContainerId)")
    }
    Start-Sleep -Seconds 2 # add 1 seconds delay for each ip to slow down the process
}



