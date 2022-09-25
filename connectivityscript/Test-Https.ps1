
<#
co-authoer: qliu
Usage: Test-Https.ps1  -HttpsUrl URL  [-Interval 20]
Output: build a TEXT output Warp on top of Invoke-WebRequest, 

Version: 1.0.20181205.1702

Change:
20220819   sample curl command 

internal 3 seconds, continous visit www.bing.com , output / result merge into log
$url="www.bing.com";$interval=3;while ($true) {curl.exe -w "dns_resolution: %{time_namelookup}, tcp_established: %{time_connect}, ssl_handshake_done: %{time_appconnect}, TTFB: %{time_starttransfer}, HTTPSTATUS: %{http_code}" https://$($url)|foreach {"{0} - {1}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$_}|out-file "c:\temp\$env:computername-curl_$($url).log" -append -encoding utf8; start-sleep $interval}

internal 3 seconds, continous visit www.bing.com , output / result are splitted. 
$url="www.bing.com";$interval=3;while ($true) {curl.exe -w "dns_resolution: %{time_namelookup}, tcp_established: %{time_connect}, ssl_handshake_done: %{time_appconnect}, TTFB: %{time_starttransfer}, HTTPSTATUS: %{http_code}" https://$($url) -o "c:\temp\$($url).html"|foreach {"{0} - {1}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$_}|out-file "c:\temp\$env:computername-curl_$($url).log" -append -encoding utf8; start-sleep $interval}

20181205    Fixed bug of the sleep time calculation.  Support the mimimum interval is around 1920 milliseconds 
            (Invoke-WebRequest return time for 1 test is about 1920 milliseconds).

10:23 PM 11/14/2018    change log path & add status code , responsesize
20181114    Change output folder to current folder.
            Check if Https was in the URL. 



#>

Param (
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Url = "https://www.microsoft.com",
    
    [int32]$interval = 10,
	[string]$logpath=$env:temp,
    [switch]$NoVerboseLog 
)


$logfile= Join-Path  $logpath $($env:COMPUTERNAME+"_TestHTTPS_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")
Write-host "Log File : "$logfile -Fo Cyan 

Write-Host "Running Invoke-WebRequest test to URL: $Url every $($interval) seconds. Logs errors to screen. Press <CTRL> C to stop. " -Fo Cyan

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

$headline="TIMESTAMP,RESULT,FailCount,URL,StatusCode,ResponseSize"
$headline > $logfile

while ($killswitch -ne 0) 
{
    $timeStart = Get-Date
    try 
    {
        $strState = "Success"

        $out = Invoke-WebRequest $Url 
        $out
        #$result = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")+","+$strState+",-,"+$Url
        $failcount = 0; #reset fault count on every successful test.
        $result = ($timeStart.ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")+","+$strState+",-,"+$Url+","+$out.StatusCode+","+$out.RawContentLength
        Write-Host $result -Fo Green
        $result >> $logfile
        if(!($NoVerboseLog))
        {
            $out >> $logfile
        }    

    }
    catch 
    {
        $failcount++
        $strState = "ERROR"
        $result = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")+","+$strState+","+$failcount+" times"+","+$Url+","+$_.Exception.Response.StatusCode.Value__+","+$out.RawContentLength
        Write-Host $result -Fo Red
        $result >> $logfile

        $Error[0]   >> $logfile 
    }

    # calculate the sleep time based on running time.
    $timeEnd = Get-Date
    $timeSpan = NEW-TIMESPAN -Start $timeStart –End $timeEnd
    $sleepInterval = $interval*1000 - $timeSpan.TotalMilliseconds
    Write-Verbose "Sleep interval: $sleepInterval - Time span: $($timeSpan.Milliseconds) - Start time: $($timeStart.Second).$($timeStart.Millisecond) - End time: $($timeEnd.Second).$($timeEnd.Millisecond)"
    
    if ($sleepInterval -gt 0) 
    {
        Start-Sleep -Milliseconds $sleepInterval
    }
}

