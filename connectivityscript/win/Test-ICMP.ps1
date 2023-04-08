
<#
Author: Qing Liu
Contributor:  Wells Luo

Usage: .\test_icmp.ps1 -ipaddr %ipaddr%
Output: write ping test result to %temp%\%computername%_%ipaddr%_%starttime%.log
Ping Fail timeout is 1s and repeat without delay
Ping OK will wait for 1s and loop

Change:
2023-04-08 : Support Application Insight , Custom Event data ingression
2019-10-31 : Update out-file format to UTF-8 for supporting Application Insight Custom Log Ingress
2018-11-14 : Change default output folder to current folder. 
2018-11-06 : Rename to Test-ICMP.PS1 to align the PowerShell naming convention.  -Wei Luo
2016-09-14 : Fix the timeformat , change hh to HH


#>

Param (
    [Parameter(Mandatory=$true)][ValidateScript({$_ -match [IPAddress]$_ })][string]$IPAddress,
	[string]$logpath=$env:temp,
    [int]$intervalinMS=1000,
    [int]$timeout=1000,
    [int]$size=96,
    [int]$n=10,
    [switch]$forever,
    [guid]$aikey  #Provide Application Insigt instrumentation key 
)

Function Write-UTCLog ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
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

#$logfile= Join-Path $logpath $($env:COMPUTERNAME+"_Ping_"+$IPAddress+"_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")
$logfile= Join-Path $logpath $($env:COMPUTERNAME+"_Test-ICMP_"+$IPAddress+".log")

Write-UTCLog "Log File : $($logfile) , Press <CTRL> + C to stop" -color Cyan 
Write-UTCLog "IPaddress : $($IPAddress) " -color Cyan
Write-UTCLog "Interval : $($intervalinMS) (ms)" -color Cyan
Write-UTCLog "Timeout : $($timeout) (ms) " -color Cyan
Write-UTCLog "PingSize : $($size) (bytes) " -color Cyan
Write-UTCLog "Repeat : $($n) " -color Cyan
Write-UTCLog "ContinuePing : $($forever) " -color Cyan

if ([string]::IsNullOrEmpty($aikey))
{
    Write-UTCLog "AppInsight: FALSE"  "Yellow"
}
else {
    Write-UTCLog "AppInsight: TRUE "  "Cyan"
}

$killswitch=1

"TIMESTAMP,COMPUTERNAME,TYPE,LATENCY,RESULT" | Out-File $logfile -Encoding utf8 -Append
while (($killswitch -le $n) -or ($forever)) {

    $object = New-Object system.Net.NetworkInformation.Ping
    $result= $object.Send($IPAddress, $timeout, $size)
#   $result.Status
    $latency=$result.RoundtripTime
#   $latency

If (!($result.Status -eq "Success")) {
    $result = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")+",$($env:COMPUTERNAME),ERROR,"+$latency+",Ping "+$IPAddress+" Fail - Request timed out. "
    $result | Out-File $logfile -Encoding utf8 -Append
    Write-Host $result -Fo Red
    if ([string]::IsNullOrEmpty($aikey)) 
    {
        Write-Host "Info : aikey is not Specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
    } 
    else 
    {
        Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
        Send-AIEvent -piKey $aikey -pEventName "test-icmp_ps1" -pCustomProperties @{status="ERROR";message="Ping Fail - Request timed out.";target=$IPAddress.tostring();latency="-1"} 
    }
 }
 Else {
    $result =((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")+",$($env:COMPUTERNAME),INFO,"+$latency+",Ping "+$IPAddress+" OK"
    $result | Out-File $logfile -Encoding utf8 -Append
    Write-Host $result -Fo Green
    if ([string]::IsNullOrEmpty($aikey)) 
    {
        Write-Host "Info : aikey is not Specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
    } 
    else 
    {
        Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
        Send-AIEvent -piKey $aikey -pEventName "test-icmp_ps1" -pCustomProperties @{status="INFO";message="Ping OK";target=$IPAddress.tostring();latency=$latency.ToString()} 
    }
    Start-Sleep -Milliseconds $intervalinMS
 }
 $killswitch++
}
