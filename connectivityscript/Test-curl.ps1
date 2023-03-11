<#
.SYNOPSIS
DNS Test script and output to local log file
> provide url
> specify TEXT file contains a list of url test and resolver ip address. 
> specify repeat count

.DESCRIPTION
HTTP/HTTPS Test script and output to local log file
> provide url
> specify TEXT file contains a list of url test and resolver ip address. 
> specify repeat count
> CURL source code check -w https://github.com/curl/curl/blob/master/src/tool_writeout.c

.PARAMETER url
The url to be tested by curl

.PARAMETER urlfile
Provide URLFile that contains list of url and resolve

.PARAMETER logfile
Provide Logfile path and filename

.PARAMETER timeout
CURL timeout in seconds, default 3.  --connect-timeout  (default:15) 

.PARAMETER count 
Total execution of $url or $urlfile (Default: 10)

.PARAMETER deplay
Milliseconds, dely between each execution of $url, but there is no delay within in $urlfile (Default: 1000)

.EXAMPLE
.\Test-Curl.ps1 -delay 0 -url https://www.bing.com 

.EXAMPLE
hard code ip address 
.\Test-Curl.ps1 -delay 0 -url https://www.bing.com -urlipaddr 1.1.1.1 

.EXAMPLE
.\Test-Curl.ps1 -delay 0 -urlfile D:\temp\urlfile.txt -timeout 1

.EXAMPLE
.\Test-Curl.ps1 -delay 0 -urlfile D:\temp\urlfile.txt -timeout 1 -logfile d:\temp\a.log

#>

Param (
       [string]$url, # input value
       [string]$urlipaddr, #specify ip address your want to Host resolve to 
       [string]$urlfile,
       [int]$timeout=3,  # CURL timeout in seconds, default 3. NOTE, --connect-timeout  (default:15) 
       [int]$count=10,  # Total execution of $url or $urlfile (Default: 10)
       [int]$delay=1000, # Milliseconds, dely between each execution of CURL (Default: 1000)
       [string]$logfile, #Provide Logfile path and filename, 
       [guid]$aikey  #Prive ApplicationInsigt Instrument Key to enable AI collect data
)

Function SendEvent{
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
                    "ai.device.id" = $env:COMPUTERNAME
                    "ai.device.locale" = $domainname
                    "ai.user.id" = $uname
                    "ai.user.authUserId" = "$($domainname)\$($uname)"
                    "ai.cloud.roleInstance" = $env:COMPUTERNAME
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
                Invoke-WebRequest -Method POST -Uri $appInsightsEndpoint -Headers @{"Content-Type"="application/x-json-stream"} -Body $body -TimeoutSec 4 -UseBasicParsing| Out-Null 
                return    
            }
            catch {
                $PreciseTimeStamp=($timeStart.ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
                if ($attempt -ge 3)
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
    
Function Write-Log ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

Function invoke_curl([string]$url,[string]$ipaddr)
{
    $cmd="curl.exe -k --connect-timeout $($timeout) -s -w ""remote_ip:%{remote_ip},dns_resolution:%{time_namelookup},tcp_established:%{time_connect},ssl_handshake_done:%{time_appconnect},TTFB:%{time_starttransfer},httpstatus:%{http_code},size_download:%{size_download}"" $($url) -o $($env:temp)\$($env:computername)_curl_result.html"
    if ([string]::IsNullOrEmpty($ipaddr)) {}
    else {
        #samples  --resolve www.bing.com:80:8.8.8.8
        $hostname=$url.split('/')[2]
        $protocol=$url.split(':')[0].ToLower()
        switch ($protocol) {
            "http" {$cmd=$cmd+" --resolve $($hostname):80:$($ipaddr)"}
            "https" {$cmd=$cmd+" --resolve $($hostname):443:$($ipaddr)"}
            Default {$cmd=$cmd}  #unknonw protocol, leave $url untouched. 
        }
    }
    #$cmd 
    # Execute CURL and get output and duration
    $duration=(measure-command {$result=Invoke-Expression $cmd }).TotalSeconds
    $PreciseTimeStamp=((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    $Message="syscost:$($duration),$($url),$($ipaddr),$($result)"
    "$($PreciseTimeStamp),$($Message)"
    "$($PreciseTimeStamp),$($Message)" | Out-File $logfile -Append -Encoding utf8
    
    if ([string]::IsNullOrEmpty($aikey)) {} 
    else 
    {
        #$headline="TIMESTAMP,RESULT,DestIP,DestPort,Message,FailCount,HOSTNAME"
        #Write-Log " Send AI...."  "Yellow"
        SendEvent -piKey $aikey -pEventName "test-curl" -pCustomProperties @{PreciseTimeStamp=$PreciseTimeStamp;Message=$Message.ToString()} 
    }
}

#main
If ([string]::IsNullOrEmpty($logfile)) 
{
    # use default path $env:temp , $env:computename, TEST-DNS, utc timestamp 
    $logfile= Join-Path  $($env:temp) $($env:COMPUTERNAME+"_Test-CURL_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")
}
Write-Log " LogFile   : $($logfile)"
Write-Log " Timeout   : $($timeout)" 
Write-Log " Count     : $($count)" 
Write-Log " Delay(ms) : $($delay)"

if ([string]::IsNullOrEmpty($aikey))
{
    Write-Log " AppInsight: TRUE"  "Green"
}
else {
    Write-Log " AppInsight: FALSE"  "Yellow"
}
#$header="TIMESTAMP,SystemCost,Url,URLIpAddress,dns_resolution,tcp_established,ssl_handshake_done,TTFB,httpstatus,SizeOfRequest"
$header|Out-File $logfile -Encoding utf8

if ([string]::IsNullOrEmpty($url) -and [string]::IsNullOrEmpty($urlfile)) 
{
    $url="https://www.bing.com"
    Write-Log " -url and -urlfile both empty, use default 'http://www.bing.com' to test" -color Yellow
    if ([string]::IsNullOrEmpty($urlipaddr)) {} else { Write-Log " URLIPAddr : $($urlipaddr)" "green"}
    for ($i=1;$i -le $count;$i++)  { 
        invoke_curl -url $url -ipaddr $urlipaddr
        start-sleep -Milliseconds $delay 
    }
}
else {
    if ([string]::IsNullOrEmpty($urlfile)) 
    {
        Write-Log " URL       : $($url)"  "green"
        if ([string]::IsNullOrEmpty($urlipaddr)) {} else { Write-Log " URLIPAddr : $($urlipaddr)" "green"}        
        for ($i=1;$i -le $count;$i++) { 
            invoke_curl -url $url -ipaddr $urlipaddr
            start-sleep -Milliseconds $delay
        }
    }
    else {
        Write-Log " URLlist   : $($urlfile)" "green"
        if (Test-Path $urlfile)
        {
            $urllist=get-content $urlfile
            Write-Log " TotalURLs : $($urllist.count)"  "green"
            for ($i=1;$i -le $count;$i++) 
            { 
                $j=1
                foreach ($link in $urllist)
                {
                    $urlitem="";$urlip=""
                    $urlip=$link.split(';')[0]
                    $urlitem=$link.split(';')[1]
                    if ([string]::IsNullOrEmpty($urlitem)){
                        Write-log " Url $($j)/$($urllist.count) : (empty) , skipping invoke_curl.... "  "yellow"
                    }
                    else{
                        Write-Log " Url $($j)/$($urllist.count) : $($urlitem)   UrlIpAddr  : $($urlip)"   "Green"
                        invoke_curl -url $urlitem -ipaddr $urlip
                        start-sleep -Milliseconds $delay
                    }
                    $j++
                }
            }
        }
        else {
            Write-Log "$($urlfile) does not exsit, please double-check!"  "Yellow"
        }
    }
}
