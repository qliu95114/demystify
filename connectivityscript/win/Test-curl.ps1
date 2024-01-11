<#
.SYNOPSIS
HTTP script (based on Curl) and output to local log file
> Support hardcode --resolve ip address
> Support TEXT file contains a list of urls 
> Support Repeat count
> Support CURL timeout
> Support delay between each execution of CURL
> Support Application Insight logging
> Support Capture HTTP headers

.DESCRIPTION
HTTP/HTTPS Test script and output to local log file
> CURL source code check -w https://github.com/curl/curl/blob/master/src/tool_writeout.c

.PARAMETER url
Provide URL to be tested 

.PARAMETER urlfile
Provide URLFile that contains list of url and resolve

.PARAMETER logfile
Provide Logfile path and filename

.PARAMETER timeout
CURL timeout in seconds, default 3.  --connect-timeout  (curl native default:15) 

.PARAMETER count 
Total execution of $url or $urlfile (Default: 10) , 0 - Forever

.PARAMETER deplay
Milliseconds, dely between each execution of $url, but there is no delay within in $urlfile (Default: 1000)

.PARAMETER aikey
GUID, Instrumentation Key used by Application Insight

.PARAMETER httpheaders
Give the options for if we want to capture the http headers, we can use ; to include multiple headers for example "X-Azure-Ref;Content-Type"

.PARAMETER httprequestheaders
Give the options for if we want to add http request headers, we can use ; to include multiple headers for example "connection: close; User-Agent: curl/7.55.1-powershell; Accept: */*"

.PARAMETER containerid
(Optional) ContainerId, if not provided, try to get it from goalstate (this assume we are running in Azure VM)


.EXAMPLE
Flood test https://www.bing.com without no delay in between
.\Test-Curl.ps1 -delay 0 -url https://www.bing.com 

.EXAMPLE
Flood test https://www.bing.com and hard code webserver ip address 1.1.1.1, without no delay in between
.\Test-Curl.ps1 -delay 0 -url https://www.bing.com -urlipaddr 1.1.1.1 

.EXAMPLE
Using a d:\temp\urlfile.txt (you can have a list of URLs) and confirm curl timeout is 1 second
.\Test-Curl.ps1 -delay 0 -urlfile D:\temp\urlfile.txt -timeout 1

.EXAMPLE
Flood https://www.bing.com and confirm curl timeout is 1 second, save result to custom log d:\temp\a.log
.\Test-Curl.ps1 -delay 0 -url https://www.bing.com  -timeout 1 -logfile d:\temp\a.log

.EXAMPLE
Flood https://www.bing.com and confirm curl timeout is 1 second, send the result to Application Insight and default log file
.\Test-Curl.ps1 -delay 0 -url https://www.bing.com  -timeout 1 -aikey 11111111-1111-1111-1111-111111111111

.EXAMPLE
Test https://www.bing.com and confirm curl timeout is 1 second , capture http headers X-Azure-Ref and Content-Type
.\Test-Curl.ps1 -url https://www.bing.com  -timeout 1 -httpheaders "X-Azure-Ref,Content-Type"

#>

Param (
       [string]$url, # input value
       [string]$urlipaddr, #specify ip address your want to Host resolve to 
       [string]$urlfile,
       [int]$timeout=3,  # CURL timeout in seconds, default 3. NOTE, --connect-timeout  (default:15) 
       [int]$count=10,  # Total execution of $url or $urlfile (Default: 10,  0:forever) 
       [int]$delay=1000, # Milliseconds, dely between each execution of CURL (Default: 1000)
       [string]$logfile, #Provide Logfile path and filename, 
       [string]$containerid,
       [string]$httpheaders, #provider http headers need be captured , for example "X-Azure-Ref;Content-Type"
       [string]$httprequestheaders, #provider http request headers, for example "connection: close; User-Agent: curl/7.55.1-powershell; Accept: */*"
       [guid]$aikey,  #Provide Application Insigt instrumentation key 
       [switch]$debug
)

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


Function Write-UTCLog ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

Function invoke_curl([string]$url,[string]$ipaddr,[string]$containerid,[string]$httpheaders,[string]$httprequestheaders)
{
    # give me random guid in case we need run multiple curl in parallel
    $guid = [guid]::NewGuid().ToString()
    # if $httprequestheaders is not empty, append it to $cmd
    if ([string]::IsNullOrEmpty($httprequestheaders))
    {
        $cmd="curl.exe -k --connect-timeout $($timeout) -s -w ""remote_ip:%{remote_ip},dns_resolution:%{time_namelookup},tcp_established:%{time_connect},ssl_handshake_done:%{time_appconnect},TTFB:%{time_starttransfer},httpstatus:%{http_code},size_download:%{size_download}"" $($url) -o $($env:temp)\$($env:computername)_curl_result_$($guid).html -D $($env:temp)\$($env:computername)_curl_header_$($guid).txt"
    }
    else {
        # split $httprequestheaders by ';'
        $requestheaders=""
        $httprequestheaders.split(';') | foreach { 
            $requestheaders=$requestheaders+" --header ""$($_)""" 
        }
        $cmd="curl.exe -k --connect-timeout $($timeout) -s -w ""remote_ip:%{remote_ip},dns_resolution:%{time_namelookup},tcp_established:%{time_connect},ssl_handshake_done:%{time_appconnect},TTFB:%{time_starttransfer},httpstatus:%{http_code},size_download:%{size_download}"" $($requestheaders) $($url) -o $($env:temp)\$($env:computername)_curl_result_$($guid).html -D $($env:temp)\$($env:computername)_curl_header_$($guid).txt"
    }

    if ($debug) {Write-Host "Debug(Curl.exe) : $($cmd)" -ForegroundColor "DarkBlue"}
    
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
    $Message="syscost:$($duration),$($url),$($ipaddr),$($result),$($containerid),$($httprequestheaders)"

     if ($debug) {Write-Host "Debug(Message) : $($Message)" -ForegroundColor "DarkBlue"}

    # append headers to $message if $httpheaders is not empty and $($env:computername)_curl_header_$($guid).txt exist
    if ([string]::IsNullOrEmpty($httpheaders)) {} else {
        if (Test-Path "$($env:temp)\$($env:computername)_curl_header_$($guid).txt") {
            $headers=get-content "$($env:temp)\$($env:computername)_curl_header_$($guid).txt"
            $httpheaders.split(';') | foreach { 
                $headername=$_.split(':')[0]
                $header=$headers | where {$_ -like "$($headername):*"}
                if ([string]::IsNullOrEmpty($header)) {} else {$Message=$Message+",$($header)"}
            }
            if ($debug) {Write-Host "Debug(GetResponseHeaders) : $($Message)" -ForegroundColor "DarkBlue"}
        }
        else {
            Write-UTCLog "Warning : HTTPHeaders ($($httpheaders)) is specified, but $($env:temp)\$($env:computername)_curl_header_$($guid).txt does not exist, skip append headers to message" -ForegroundColor "Yellow"
        }
    }

    "$($PreciseTimeStamp),$($Message)"
    "$($PreciseTimeStamp),$($Message)" | Out-File $logfile -Append -Encoding utf8
  
    #remove temp file generated by curl.exe
    Remove-Item "$($env:temp)\$($env:computername)_curl_header_$($guid).txt" -Force 
    Remove-Item "$($env:temp)\$($env:computername)_curl_result_$($guid).html" -Force

    if ([string]::IsNullOrEmpty($aikey)) {
        if ($debug) {Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"}
    } 
    else 
    {
        if ($debug) {Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"}
        Send-AIEvent -piKey $aikey -pEventName $global:scriptname -pCustomProperties @{Message=$Message.ToString()} 
    }
}

#main
If ([string]::IsNullOrEmpty($logfile)) 
{
    # use default path $env:temp , $env:computename, TEST-DNS, utc timestamp 
    $logfile= Join-Path  $($env:temp) $($env:COMPUTERNAME+"_Test-CURL_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")
}

# if containerid is empty or null, try to get it from goalstate
if ([string]::IsNullOrEmpty($containerid)) { 
    Write-UTCLog "ContainerId is empty, try to get it from goalstate" -color "Yellow"
    $containerid=([xml](c:\windows\system32\curl --connect-timeout 0.2 "http://168.63.129.16/machine?comp=goalstate" -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A """")).GoalState.Container.ContainerId
}

$global:scriptname = $MyInvocation.MyCommand.Name

Write-UTCLog " LogFile     : $($logfile)"
Write-UTCLog " Timeout     : $($timeout)" 
Write-UTCLog " Count       : $($count)" 
Write-UTCLog " Delay(ms)   : $($delay)"
Write-UTCLog " ContainerId : $($containerid)"

if ([string]::IsNullOrEmpty($aikey))
{
    Write-UTCLog " AppInsight: FALSE"  "Yellow"
}
else {
    Write-UTCLog " AppInsight: TRUE "  "Cyan"
}
#$header="TIMESTAMP,SystemCost,Url,URLIpAddress,dns_resolution,tcp_established,ssl_handshake_done,TTFB,httpstatus,SizeOfRequest"
$header|Out-File $logfile -Encoding utf8 -Append

if ([string]::IsNullOrEmpty($url) -and [string]::IsNullOrEmpty($urlfile)) 
{
    $url="https://www.bing.com"
    Write-UTCLog " -url and -urlfile both empty, use default 'http://www.bing.com' to test" -color Yellow
    if ([string]::IsNullOrEmpty($urlipaddr)) {} else { Write-UTCLog " URLIPAddr : $($urlipaddr)" "green"}
    if ([string]::IsNullOrEmpty($httprequestheaders)) {} else { Write-UTCLog " HTTP_Request_Header : $($httprequestheaders)" "green"}
    if ($count -ne 0)
    {
        # run $count curl test
        for ($i=1;$i -le $count;$i++)  { 
            Write-UTCLog " Url $($i)/($count) : $($url)   UrlIpAddr  : $($urlipaddr)"   "Green"            
            # caculate duration of curl.exe
            $syscost=Measure-Command {invoke_curl -url $url -ipaddr $urlipaddr -containerid $containerid -httpheaders $httpheaders -httprequestheaders $httprequestheaders}
            if (($delay - $syscost.TotalMilliseconds) -gt 0 )
                {
                    Write-UTCLog " Sleep $($delay - $syscost.TotalMilliseconds) ms" "gray"
                    start-sleep -Milliseconds ($delay - $syscost.TotalMilliseconds)
                }
                else {
                    Write-UTCLog " Overdue : Sleep 0 ms" "red"
                }                
        }
    }
    else {
        # count = 0 and make it forever
        $i=1
        while ($true)   
        {
            Write-UTCLog " Url $($i)/Forever : $($url)   UrlIpAddr  : $($urlipaddr)"   "Green"            
            $syscost=Measure-Command {invoke_curl -url $url -ipaddr $urlipaddr -containerid $containerid -httpheaders $httpheaders -httprequestheaders $httprequestheaders}
            if (($delay - $syscost.TotalMilliseconds) -gt 0 )
                {
                    Write-UTCLog " Sleep $($delay - $syscost.TotalMilliseconds) ms" "gray"
                    start-sleep -Milliseconds ($delay - $syscost.TotalMilliseconds)
                }
                else {
                    Write-UTCLog " Overdue : Sleep 0 ms" "red"
                }
            $i++
        }
    }

}
else {
    if ([string]::IsNullOrEmpty($urlfile)) 
    {
        Write-UTCLog " URL       : $($url)"  "green"
        if ([string]::IsNullOrEmpty($urlipaddr)) {} else { Write-UTCLog " URLIPAddr : $($urlipaddr)" "green"}        
        if ([string]::IsNullOrEmpty($httprequestheaders)) {} else { Write-UTCLog " HTTP_Request_Header : $($httprequestheaders)" "green"}
        if ($count -ne 0)
        {
            for ($i=1;$i -le $count;$i++) { 
                Write-UTCLog " Url $($i)/$($count) : $($url)   UrlIpAddr  : $($urlipaddr)"   "Green"            
                $syscost=Measure-Command {invoke_curl -url $url -ipaddr $urlipaddr -containerid $containerid -httpheaders $httpheaders -httprequestheaders $httprequestheaders}
                if (($delay - $syscost.TotalMilliseconds) -gt 0 )
                    {
                        Write-UTCLog " Sleep $($delay - $syscost.TotalMilliseconds) ms" "gray"
                        start-sleep -Milliseconds ($delay - $syscost.TotalMilliseconds)
                    }
                    else {
                        Write-UTCLog " Overdue : Sleep 0 ms" "red"
                    }    
            }
        }
        else{
            # count = 0 and make it forever
            $i=1
            while ($true)   
            {
                Write-UTCLog " Url $($i)/Forever : $($url)   UrlIpAddr  : $($urlipaddr)"   "Green"            
                $syscost=Measure-Command {invoke_curl -url $url -ipaddr $urlipaddr -containerid $containerid -httpheaders $httpheaders -httprequestheaders $httprequestheaders}
                if (($delay - $syscost.TotalMilliseconds) -gt 0 )
                    {
                        Write-UTCLog " Sleep $($delay - $syscost.TotalMilliseconds) ms" "gray"
                        start-sleep -Milliseconds ($delay - $syscost.TotalMilliseconds)
                    }
                    else {
                        Write-UTCLog " Overdue : Sleep 0 ms" "red"
                    }    
                $i++
            }
        }
    }
    else {
        Write-UTCLog " URLlist   : $($urlfile)" "green"
        if (Test-Path $urlfile)
        {
            $urllist=get-content $urlfile
            Write-UTCLog " TotalURLs : $($urllist.count)"  "green"

            if ($count -ne 0)
            {
                for ($i=1;$i -le $count;$i++) 
                { 
                    $j=1
                    foreach ($link in $urllist)
                    {
                        $urlitem="";$urlip=""
                        $urlip=$link.split(';')[0]
                        $urlitem=$link.split(';')[1]
                        if ([string]::IsNullOrEmpty($urlitem)){
                            Write-UTCLog " Url $($j)/$($urllist.count) - $($i)/$($count) : (empty) , skipping invoke_curl.... "  "yellow"
                        }
                        else{
                            Write-UTCLog " Url $($j)/$($urllist.count) - $($i)/$($count) : $($urlitem)   UrlIpAddr  : $($urlip)"   "Green"
                            $syscost=Measure-Command {invoke_curl -url $url -ipaddr $urlipaddr -containerid $containerid -httpheaders $httpheaders -httprequestheaders $httprequestheaders}
                            if (($delay - $syscost.TotalMilliseconds) -gt 0 )
                                {
                                    Write-UTCLog " Sleep $($delay - $syscost.TotalMilliseconds) ms" "gray"
                                    start-sleep -Milliseconds ($delay - $syscost.TotalMilliseconds)
                                }
                                else {
                                    Write-UTCLog " Overdue : Sleep 0 ms" "red"
                                }    
                        }
                        $j++
                    }
                }
            }
            else {
                $i=1
                while ($true)
                {
                    $j=1
                    foreach ($link in $urllist)
                    {
                        $urlitem="";$urlip=""
                        $urlip=$link.split(';')[0]
                        $urlitem=$link.split(';')[1]
                        if ([string]::IsNullOrEmpty($urlitem)){
                            Write-UTCLog " Url $($j)/$($urllist.count) - $($i)forever : (empty) , skipping invoke_curl.... "  "yellow"
                        }
                        else{
                            Write-UTCLog " Url $($j)/$($urllist.count) - $($i)/forever : $($urlitem)   UrlIpAddr  : $($urlip)"   "Green"
                            $syscost=Measure-Command {invoke_curl -url $url -ipaddr $urlipaddr -containerid $containerid -httpheaders $httpheaders -httprequestheaders $httprequestheaders}
                            if (($delay - $syscost.TotalMilliseconds) -gt 0 )
                                {
                                    Write-UTCLog " Sleep $($delay - $syscost.TotalMilliseconds) ms" "gray"
                                    start-sleep -Milliseconds ($delay - $syscost.TotalMilliseconds)
                                }
                                else {
                                    Write-UTCLog " Overdue : Sleep 0 ms" "red"
                                }    
                        }
                        $j++
                    }
                    $i++
                }
            }

        }
        else {
            Write-UTCLog "$($urlfile) does not exsit, please double-check!"  "Yellow"
        }
    }
}

