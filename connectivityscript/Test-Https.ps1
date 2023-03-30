
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
    [switch]$VerboseLog
)

Function Write-UTCLog ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

$logfile= Join-Path $logpath $($env:COMPUTERNAME+"_TestHTTPS_$($url.split('/')[2])_$((get-date).ToUniversalTime().ToString('yyyyMMddTHHmmss')).log")
Write-UTCLog "Log File : $($logfile)" -color "Cyan"

Write-UTCLog "Running Invoke-WebRequest(IWR) test, press CTRL + C to stop" 
Write-UTCLog "URL : $($Url) "  "Yellow"
Write-UTCLog "Interval : $($intervalinMS) (ms)" -color "Yellow"
Write-UTCLog "IWR_Timeout : $($timeout) (s)" -color "Yellow"

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

$killswitch=1
$failcount=0

$headline="TIMESTAMP,COMPUTERNAME,RESULT,FailCount,URL,StatusCode,ResponseSize"
$headline | Out-File $logfile -Encoding utf8

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
        $result = "$((get-date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')),$($env:COMPUTERNAME),$($strState),$($failcount),$($Url),$($_.Exception.Response.StatusCode.Value),$($out.RawContentLength)"
        Write-Host $result -Fo "Red"
        $result >> $logfile
        $Error[0] | Out-File $logfile -Encoding utf8 -Append
    }

    # calculate the sleep time based on running time.
    $timeEnd = Get-Date
    $timeSpan = NEW-TIMESPAN -Start $timeStart –End $timeEnd
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

