
<#
Author: Qing Liu
Contributor:  Wells Luo

Usage: test_icmp.ps1 -ipaddr %ipaddr%
Output: write ping test result to %temp%\%computername%_%ipaddr%_%starttime%.log
Ping Fail timeout is 1s and repeat without delay
Ping OK will wait for 1s and loop

Change:
10:17 PM 10/31/2019  : Update out-file format to UTF8 for custom log upload
20181114  Change default output folder to current folder. 
20181106  Rename to Test-ICMP.PS1 to align the PowerShell naming convention.  -Wei Luo
11:26 AM 2016-09-14 fix the timeformat , change hh to HH

Version:  1.0.20181114.1755
#>

Param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({$_ -match [IPAddress]$_ })]    
    [string]$IPAddress,
	[string]$logpath=$env:temp,
    [int]$intervalinMS=1000,
    [int]$timeout=1000,
    [int]$size=96,
    [int]$n=10,
    [switch]$forever
)

Function Write-UTCLog ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

$logfile= Join-Path $logpath $($env:COMPUTERNAME+"_Ping_"+$IPAddress+"_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")

Write-UTCLog "Log File : $($logfile) , Press <CTRL> + C to stop" -color Cyan 
Write-UTCLog "IPaddress : $($IPAddress) " -color Cyan
Write-UTCLog "Interval : $($intervalinMS) (ms)" -color Cyan
Write-UTCLog "Timeout : $($timeout) (ms) " -color Cyan
Write-UTCLog "PingSize : $($size) (bytes) " -color Cyan
Write-UTCLog "Repeat : $($n) " -color Cyan
Write-UTCLog "ContinuePing : $($forever) " -color Cyan

$killswitch=1

"TIMESTAMP,COMPUTERNAME,TYPE,LATENCY,RESULT" | Out-File $logfile -Encoding utf8
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
 }
 Else {
    $result =((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")+",$($env:COMPUTERNAME),INFO,"+$latency+",Ping "+$IPAddress+" ok"
    $result | Out-File $logfile -Encoding utf8 -Append
    Write-Host $result -Fo Green
    Start-Sleep -Milliseconds $intervalinMS
 }
 $killswitch++
}
