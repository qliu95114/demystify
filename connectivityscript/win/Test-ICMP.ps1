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
    [int]$Timeout=1000,
    [int]$size=96,
    [int]$n=10,
    [switch]$forever,
    [guid]$aikey,  #Provide Application Insigt instrumentation key 
    [string]$containerid,
    # a parameter only accept 0,1,2,3,4
    [ValidateSet(0,1,2,3,4)][int]$TimedLog=0  # 0: Disable, 1: Every Minutes, 2, Every 10 Minutes: 3: Every 1 Hour, 4: Every 1 Day
)

Function Write-UTCLog ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
    }


#Create Timed Loggging Function
Function AppendTimedLog ([string]$message,[string]$logfile,[int]$TimedLog=0) 
#message already have timestamps , this function just decide the which logfile need send the entry to
#1: Every Minutes, 2, Every 10 Minutes: 3: Every 1 Hour, 4: Every 1 Day
{
    switch ($TimedLog) {
        1 { 
            #create timestamp every minutes
            $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd_HHmm") 
            $logfile = $logfile.split(".log")[0]+"_"+$logdate+".log"
          }
        2 {
            #create timestamp and round to 10 minutes
            $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd_HHmm") 
            #remove the last 1 digit
            $logdate = $logdate.substring(0,$logdate.length-1)
            $logfile = $logfile.split(".log")[0]+"_"+$logdate+"0.log"
          }
        3 {
            #create timestamp and round to 1 hour
            $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd_HHmm") 
            #remove the last 2 digit
            $logdate = $logdate.substring(0,$logdate.length-2)
            $logfile = $logfile.split(".log")[0]+"_"+$logdate+"00.log"
          }
        4 {
            #create timestamp and round to 1 day
            $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd_HHmm")
            #remove the last 4 digit
            $logdate = $logdate.substring(0,$logdate.length-4)
            $logfile = $logfile.split(".log")[0]+"_"+$logdate+"0000.log"
          }
        Default {}
    }

    if (Test-Path $logfile) {
        #Write-UTCLog "Log File : $($logfile) exist, skip create a new one" -color Cyan 
    }
    else {
        Write-UTCLog "New Log File : $($logfile) , Press <CTRL> + C to stop" -color Cyan 
        "TIMESTAMP,CONTAINERID,COMPUTERNAME,TYPE,LATENCY,RESULT" | Out-File $logfile -Encoding utf8 
    }    
    $message | Out-File $logfile -Encoding ASCII -append
}

# Powershell Function Send-AIEvent , 2023-08-12 , fix bug in retry logic
Function Send-AIEvent{
    param (
                [Guid]$piKey,
                [String]$pEventName,
                [Hashtable]$pCustomProperties,
                [string]$logpath=$env:temp
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
                $PreciseTimeStamp=(get-date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
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

# if containerid is empty or null, try to get it from goalstate
if ([string]::IsNullOrEmpty($containerid)) { 
    Write-UTCLog "ContainerId is empty, try to get it from goalstate" -color "Yellow"
    $containerid=([xml](c:\windows\system32\curl --connect-timeout 0.2 "http://168.63.129.16/machine?comp=goalstate" -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A """")).GoalState.Container.ContainerId
}

switch ($TimedLog) {
    1 { $deltatime="Every minute" }
    2 { $deltatime="Every 10 minutes" }
    3 { $deltatime="Every 1 hour" }
    4 { $deltatime="Every 1 day" }
    Default { $deltatime="Disable"}
}

Write-UTCLog "Log File : $($logfile.Split('.log')[0])*.* , Press <CTRL> + C to stop" -color Cyan 
Write-UTCLog "TimedLog : $($TimedLog) : $($deltatime)" -color Cyan 
Write-UTCLog "ContainerId : $($containerid) " -color Cyan
Write-UTCLog "IPaddress : $($IPAddress) " -color Cyan
Write-UTCLog "Interval : $($intervalinMS) (ms)" -color Cyan
Write-UTCLog "Timeout : $($timeout) (ms) " -color Cyan
Write-UTCLog "PingSize : $($size) (bytes) " -color Cyan
if ($forever)
{
    $totalpingcount="-1"
    Write-UTCLog "ContinuePing : $($forever)"  "Yellow"
}
else {
    $totalpingcount=$n
    Write-UTCLog "Repeat : $($n) " -color Cyan
    Write-UTCLog "ContinuePing : $($forever)"  "Cyan"
}

if ([string]::IsNullOrEmpty($aikey))
{
    Write-UTCLog "AppInsight: FALSE"  "Yellow"
}
else {
    Write-UTCLog "AppInsight: TRUE "  "Cyan"
}

$killswitch=1

while (($killswitch -le $n) -or ($forever)) {

    $object = New-Object system.Net.NetworkInformation.Ping
    $result= $object.Send($IPAddress, $timeout, $size)
#   $result.Status
    $latency=$result.RoundtripTime
#   $latency

    If (!($result.Status -eq "Success")) {
        $result = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")+",$($containerid),$($env:COMPUTERNAME),ERROR,"+$latency+",Ping "+$IPAddress+" Fail - Request timed out. "
        # call AppendTimedLog function 
        AppendTimedLog -message $result -logfile $logfile -timedlog $TimedLog 
        Write-Host "($($killswitch)/$($totalpingcount)) : $($result)" -ForegroundColor Red
        if ([string]::IsNullOrEmpty($aikey)) 
        {
            Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
        } 
        else 
        {
            Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
            Send-AIEvent -piKey $aikey -pEventName "test-icmp_ps1" -pCustomProperties @{status="ERROR";message="Ping Fail - Request timed out.";target=$IPAddress.tostring();latency="-1"} 
        }
    }
    Else {
        $result =((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")+",$($containerid),$($env:COMPUTERNAME),INFO,"+$latency+",Ping "+$IPAddress+" OK"
        AppendTimedLog -message $result -logfile $logfile -timedlog $TimedLog 
        Write-Host "($($killswitch)/$($totalpingcount)) : $($result)" -ForegroundColor "Green"
        if ([string]::IsNullOrEmpty($aikey)) 
        {
            Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
        } 
        else 
        {
            Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
            Send-AIEvent -piKey $aikey -pEventName "test-icmp_ps1" -pCustomProperties @{status="INFO";message="Ping OK";target=$IPAddress.tostring();latency=$latency.ToString();containerid=$containerid.ToString()} 
        }
        Start-Sleep -Milliseconds $intervalinMS
    }
    $killswitch++
}
