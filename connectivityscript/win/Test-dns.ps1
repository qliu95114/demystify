<#
.SYNOPSIS
DNS Test script and output to local log file
> provide one DNS name 
> specify TEXT file contains a list of DNS name
> specify repeat count

.DESCRIPTION
DNS Test script and output to local log file
> provide one DNS name 
> specify TEXT file contains a list of DNS name
> specify repeat count

.PARAMETER dnsname
The name of the file to be converted, please include full path of the file , wildchar is not supported. 

.PARAMETER dnslistfile
The name of the file containing a list of DNS names to be tested, please include full path of the file , wildchar is not supported.

.PARAMETER dnsserver
Target DNS server, for example 8.8.8.8 or 168.63.129.16 

.PARAMETER logfile
Logfile 

.PARAMETER timeout
DNS Query timeout settings, default 5

.PARAMETER count 
Repeat , default 10

.PARAMETER deplay
Milliseconds, delay between each batch , default 1000

.EXAMPLE
.\Test-dns.ps1 -delay 0 -dnsname www.bing.com

.EXAMPLE
.\Test-dns.ps1 -delay 0 -dnslistfile D:\temp\dnsname.txt -timeout 1

.EXAMPLE
.\Test-dns.ps1 -delay 0 -dnslistfile D:\temp\dnsname.txt -timeout 1 -dnsserver 1.1.1.1 -logfile d:\temp\a.log

#>

Param (
    [string]$dnsname, # input value
    [string]$dnslistfile,
    [string]$dnsserver,
    [int]$timeout=5,
    [int]$count=10,
    [int]$delay=1000,
    [string]$logfile,
    [guid]$aikey,
    [switch]$ipv6
)

Function Write-UTCLog ([string]$message,[string]$color="white")
{
        $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
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


Function invoke_nslookup([string]$dns,[string]$dnsserver, [switch]$ipv6)
{
    $type = if ($ipv6) { "AAAA" } else { "A" }
    $cmd="nslookup -timeout=$($timeout) -retry=1 -type=$type $($dns). $($dnsserver)"
    $cmd
    $duration=(measure-command {$result=iex $cmd }).TotalSeconds
    for ($i=2;$i -le $result.count;$i++)  
    {
        $dnsresult+=$result[$i]+"|"
    } 
    $dnsresult=$dnsresult.trim("|")
    
    # HACKING if there is no return assume we get DNS response of NXDOAIMN
    if ([string]::IsNullOrEmpty($dnsresult)) 
    {
         $dnsresult="can't find $($dns).: Non-existent domain"
    }

    Write-UTCLog "$($duration),$($dns),$($dnsresult)" "green"
    
    $Message="$(((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")),$($duration),$($dns),$($dnsresult)"
    $Message | Out-File $logfile -Append -Encoding utf8
    if ([string]::IsNullOrEmpty($aikey)) 
    {
        Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
    } 
    else 
    {
        Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
        Send-AIEvent -piKey $aikey -pEventName $global:scriptname -pCustomProperties @{latency=$duration.tostring();target=$dns.tostring();Message=$dnsresult.ToString()} 
    }
}

#main

$global:scriptname = $MyInvocation.MyCommand.Name

If ([string]::IsNullOrEmpty($logfile)) 
{
    # use default path $env:temp , $env:computename, TEST-DNS, utc timestamp 
    $logfile= Join-Path  $($env:temp) $($env:COMPUTERNAME+"_Test-DNS_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")
}
Write-UTCLog " LogFile   : $($logfile)"
Write-UTCLog " Timeout   : $($timeout)" 
Write-UTCLog " Count     : $($count)" 
Write-UTCLog " Delay(ms) : $($delay)"

if ([string]::IsNullOrEmpty($aikey))
{
    Write-UTCLog " AppInsight: FALSE"  "Yellow"
}
else {
    Write-UTCLog " AppInsight: TRUE "  "Cyan"
}

$header="TIMESTAMP,Duration,DNSNAME,RESULT"
$header|Out-File $logfile -Encoding utf8



if ([string]::IsNullOrEmpty($dnsname) -and [string]::IsNullOrEmpty($dnslistfile)) {
    $dnsname = "www.bing.com"
    Write-UTCLog "-dnsname and -dnslistfile both empty, use default 'www.bing.com' to test"
    if ($count -eq -1) {
        while ($true) {
            invoke_nslookup -dns $dnsname -dnsserver $dnsserver -ipv6:$ipv6
            start-sleep -Milliseconds $delay
        }
    } else {
        for ($i = 1; $i -le $count; $i++) {
            invoke_nslookup -dns $dnsname -dnsserver $dnsserver -ipv6:$ipv6
            start-sleep -Milliseconds $delay
        }
    }
} else {
    if ([string]::IsNullOrEmpty($dnslistfile)) {
        Write-UTCLog " Dnsname   : $($dnsname)"
        if ($count -eq -1) {
            while ($true) {
                invoke_nslookup -dns $dnsname -dnsserver $dnsserver -ipv6:$ipv6
                start-sleep -Milliseconds $delay
            }
        } else {
            for ($i = 1; $i -le $count; $i++) {
                invoke_nslookup -dns $dnsname -dnsserver $dnsserver -ipv6:$ipv6
            }
        }
    } else {
        Write-UTCLog " DnsList   : $($dnslistfile)"
        if (Test-Path $dnslistfile) {
            $dnslist = get-content $dnslistfile
            Write-UTCLog " DnsRecord : $($dnslist.count)"
            if ($count -eq -1) {
                while ($true) {
                    foreach ($dns in $dnslist) {
                        invoke_nslookup -dns $dns -dnsserver $dnsserver -ipv6:$ipv6
                        start-sleep -Milliseconds $delay
                    }
                }
            } else {
                for ($i = 1; $i -le $count; $i++) {
                    foreach ($dns in $dnslist) {
                        invoke_nslookup -dns $dns -dnsserver $dnsserver -ipv6:$ipv6
                        start-sleep -Milliseconds $delay
                    }
                }
            }
        } else {
            Write-UTCLog "$($dnslistfile) does not exsit, please double-check!"
        }
    }
}

