
<#
co-authoer: qliu
Usage: Test-Https.ps1  -HttpsUrl URL  -IntervalinMS 2000 -timeout 3
Output: build a TEXT output Warp on top of Invoke-WebRequest, 

Version: 1.0.20181205.1702

Change:
20181205    Fixed bug of the sleep time calculation.  Support the mimimum interval is around 1920 milliseconds 
            (Invoke-WebRequest return time for 1 test is about 1920 milliseconds).

10:23 PM 11/14/2018    change log path & add status code , responsesize
20181114    Change output folder to current folder.
            Check if Https was in the URL. 

#>

Param (
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Url = "https://dns.google",
    [int]$timeout=3,
    [int]$intervalinMS=5000,  #interval is -Milliseconds,
	[string]$logpath=$env:temp,
    [switch]$VerboseLog,
    [guid]$aikey
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


#main program start
#$logfile= Join-Path $logpath $($env:COMPUTERNAME+"_TestHTTPS_$($url.split('/')[2])_$((get-date).ToUniversalTime().ToString('yyyyMMddTHHmmss')).log")
$logfile= Join-Path $logpath $($env:COMPUTERNAME+"_TestHTTPS_$($url.split('/')[2]).log")

$scriptname = $MyInvocation.MyCommand.Name

Write-UTCLog "Log File : $($logfile)" -color "Cyan"
Write-UTCLog "Running Invoke-WebRequest(IWR) test, press CTRL + C to stop" -color "Cyan"
Write-UTCLog "URL : $($Url) "  "Yellow"
Write-UTCLog "Interval : $($intervalinMS) (ms)" -color "Yellow"
Write-UTCLog "IWR_Timeout : $($timeout) (s)" -color "Yellow"
if ([string]::IsNullOrEmpty($aikey))
{
    Write-UTCLog "AppInsight: FALSE"  "Yellow"
}
else {
    Write-UTCLog "AppInsight: TRUE "  "Cyan"
}

add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$killswitch=1
$failcount=0

$headline="TIMESTAMP,COMPUTERNAME,RESULT,FailCount,URL,StatusCode,ResponseSize"
$headline | Out-File $logfile -Encoding utf8 -Append

while ($killswitch -ne 0) 
{
    $timeStart = Get-Date
    try 
    {
        $strState = "Success"

        $out = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec $timeout
        #$result = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")+","+$strState+",-,"+$Url
        $failcount = 0; #reset fault count on every successful test.
        $result = "$($timeStart.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')),$($env:COMPUTERNAME),$($strState),0,$($Url),$($out.StatusCode),$($out.RawContentLength)"
        Write-Host $result -Fo "Cyan"
        $result |Out-File $logfile -Encoding utf8 -Append
        
        if ([string]::IsNullOrEmpty($aikey)) {
            Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
        } 
        else 
        {
            Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
            Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{result=$strState.tostring();url=$Url.tostring();failcount="0";httpstatus=$out.StatusCode.tostring();responsesize=$out.RawContentLength.ToString()} 
        }

        if($VerboseLog)
        {
            $out.RawContent
            $out.RawContent | Out-File $logfile -Encoding utf8 -Append
        }    

    }
    catch 
    {
        $failcount++
        $strState = "ERROR"
        $result = "$((get-date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')),$($env:COMPUTERNAME),$($strState),$($failcount),$($Url),$($_.Exception.Message),"
        Write-Host $result -Fo "Red"
        $result |Out-File $logfile -Encoding utf8 -Append

        if ([string]::IsNullOrEmpty($aikey)) {
            Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
        } 
        else 
        {
            Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
            Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{result=$strState.tostring();url=$Url.tostring();failcount=$failcount.tostring();httpstatus=$_.Exception.Message.tostring();responsesize="0"} 
        }

        if($VerboseLog)
        {
            $Error[0]
            $Error[0] | Out-File $logfile -Encoding utf8 -Append
        }
    }

    # calculate the sleep time based on running time.
    $timeEnd = Get-Date
    $timeSpan = NEW-TIMESPAN -Start $timeStart -End $timeEnd
    $sleepInterval = $intervalinMS - $timeSpan.TotalMilliseconds 
    if ($sleepInterval -gt 0)
    {
        Write-UTCLog "Sleep (ms): $($sleepInterval) - LastRequestTimeCost(ms): $($timeSpan.Milliseconds)"  "Green"
        Start-Sleep -Milliseconds $sleepInterval
    }
    else {
        Write-UTCLog "Sleep (ms): 0 - LastRequestTimeCost(ms): $($timeSpan.Milliseconds)"  "Yellow"
    }
}

