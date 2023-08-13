<#
    .NOTES
        THE SAMPLE SOURCE CODE IS PROVIDED "AS IS", WITH NO WARRANTIES.
    
        Author: Qing Liu, Wells Luo

    .SYNOPSIS
        Build a TEXT output Warp on top of PSPING, it fails fast compared with Test-NetConnection

        Dependencies:  PowerShell Version 4.0 or above.

    .DESCRIPTION
        Keep running PSPING to target to text the connection.
        Build a TEXT output Warp on top of PSPING.

    .EXAMPLE
        Test-PSPing.ps1  -FQDN www.microsoft.com  -Port 80  -logpath ".\"

    .OUTPUTS
        Log file.
        psping -n 1 and read output 
        lost=1 means packet loss and output the last line of connection status
        lost=0 means no packet loss and output the last line with destip:destport sourceip:sourceport latency 

    Version    20190301.1616

   
#>

<#
Change:

10:17 PM 10/31/2019  : Update out-file format to UTF8 for custom log upload

20190301    Update the download URL of PSPing. Directly download .exe file. 
            Remove the dependency to expand .ZIP file to get PSPING exe file.
            Check CPU architecture, download PSPing64.exe with AMD64, otherise PSPING.exe.
            Bug fix when providing ".\" as log file path. 
            Update the head of the script file to support standard PS help. 

20190218    Bug fix in PSVersion 4.0. Use .Net funcation call to extract zip file. 
                .Net 4.5 or above is needed.
                .Net Core 1.0 or above is needed

            Update the work flow for PSPing.exe
                - Check if PSPing is in $logpath
                    - if not, then check if it is in $logpath+"PSTools" folder
                        - if not, check if PSTools.zip is already downloaded.
                            - if not, download it from Internet.
                        -Extract PSTools.zip to PSTools folder.
                    - Copy PSPing.exe to $logpath
                - Run PSPing.exe
20181205    Add parameter "AsJob" to stop file downloading prompt.  So the script can be integrated into other 
            script/automation.
            Fixed bug of the sleep time calculation.  Support the mimimum interval is around 1120 milliseconds 
            (PSPing return time for 1 ping is about 1120 milliseconds).
20181114    Set default log output folder to current folder (in which runs the script).
            Support FQDN as input.
20181106    Support to download PSPing.exe from Internet. 
            Remove email feature. 
2017-04-11T 05:31:26 (UTC) : update time format to fit customer log requirement in OMS Customer log
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-sources-custom-logs 
11:26 AM 2016-09-14 fix the timeformat , change hh to HH
2:51 PM 2016-12-18 add -path to support specified output folder

#>



[CmdLetBinding(DefaultParameterSetName="IPADDRESS")]
Param (
    
    [Parameter(ParameterSetName="IPADDRESS", Mandatory=$true, Position=0)]
    [ValidateScript({$_ -match [IPAddress]$_ })]    
    [string]$IPAddress,
    
    [Parameter(ParameterSetName="FQDN", Mandatory=$true, Position=0)]  
    [string]$FQDN,


    [Parameter(Mandatory=$true, Position=1)]
    [ValidateRange(0, 65535)]
    [string]$Port,
    
    [Parameter(Mandatory=$false)]
    [Alias("Output")]
    [ValidateScript({Test-Path $_})]    
	[string]$logpath=$env:temp,
    
    [int32]$Interval = 10,
    [string]$aikey,
   
    [Switch]$AsJob
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
    

# Start main scription

switch ($PSCmdlet.ParameterSetName) 
{
    "IPADDRESS" 
        {
            Write-Verbose "IP address from input: $IPAddress "
        }

    "FQDN"
        {
            try 
            {
                $fqdnObj = Resolve-DnsName $FQDN -Type A -ErrorAction Stop
            }
            catch 
            {
                Write-Host "Invalid input, $($Error[0])"  -ForegroundColor Red
                Exit -1
            }

            $IPAddress = $fqdnObj.IPAddress
            Write-Verbose "FQDN from input: $FQDN - resolved IP address: $IPAddress"
        }    
    Default {}
}

Write-Host "`nRunning PSPING TCP test to $IPAddress : $port every $Interval seconds. Logs erros to screen. Press <CTRL> C to stop. `n" -Fo Cyan


# Get the full path of $logpath if it was provided as local path .\
$logpath = (Get-Item $logpath).FullName

# Set log file to $logpath, name with current time.
$logfile= Join-Path  $logpath $($env:COMPUTERNAME+"_PSPING_"+$IPAddress+"_"+$port+"_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")
Write-host "Log File : "$logfile -Fo Cyan 

$killswitch=1
$failcount=0

$headline="TIMESTAMP,RESULT,DestIP,DestPort,Message,FailCount,HOSTNAME"
$headline |Out-File $logfile -Encoding utf8 

# PSPing.exe/PSPing64.exe local path. 

if ($env:PROCESSOR_ARCHITECTURE -match "AMD64") 
{
    Write-Verbose "x64 machine, PSPING64.exe will be used"
    $pspingFileName = "psping64.exe"
    $pspingDownloadUrl = "https://live.sysinternals.com/psping64.exe"    
}
else 
{
    Write-Verbose "x86 machine, PSPING.exe will be used"
    $pspingFileName = "psping.exe"
    $pspingDownloadUrl = "https://live.sysinternals.com/psping.exe"    
}

# setting local path to script current folder
$pspingLocalFullPath = Join-Path $PSScriptRoot $pspingFileName

# checking if PSPing/64.exe is in the script folder
If (!(Test-Path $pspingLocalFullPath -PathType Leaf))
{
    # setting local path to logpath folder to see if PSPing/64.exe is there (if not in the script folder)
    $pspingLocalFullPath = Join-Path $logpath $pspingFileName

    # checking if PSPing/64.exe is in the logpath folder (if not try to download it)
    If (!(Test-Path $pspingLocalFullPath -PathType Leaf)) 
    {
        # download from Internet.
        If (!$AsJob) 
        {   # In interactive mode, prompt user the file download. 
            # In Job mode, download directly if the file doesn't exist. 
    
            # confirm to download the PSTool.zip
            Write-host "The script will download $pspingFileName from Microsoft Systeminternals web site: $pspingDownloadUrl" -ForegroundColor Cyan
            Write-Host "Please confirm if the download is allowed: Y/N " -ForegroundColor Yellow  -NoNewline
            $keyPressed = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            # Y and Enter key are accepted to download. other keys are not.
            if (($keyPressed.VirtualKeyCode -ne 89) -and ($keyPressed.VirtualKeyCode -ne 13)) 
            {
                # Download is not allowed. 
                Write-Host $keyPressed.Character.ToString().ToUpper()  -ForegroundColor Red
                Write-Host "Download $pspingFileName is not allowed." -ForegroundColor Red
                Write-Host "Please manully download $pspingFileName from $pspingDownloadUrl and copy $pspingFileName to the same folder of this script.`n Run script again."
                Exit -1
            }
    
            Write-Host $keyPressed.Character.ToString().ToUpper()  -ForegroundColor Green
            
        }
        # Download is allowed.
        $webClient = New-Object System.Net.WebClient
        Try 
        {
            Write-Host "Downloading $pspingFileName ..." -ForegroundColor Cyan
            $webClient.DownloadFile($pspingDownloadUrl, $pspingLocalFullPath)
            Write-Host "Downloaded $pspingFileName to folder  $pspingLocalFullPath." -ForegroundColor Cyan
        }
        Catch 
        {
            Write-Host "Cannot download $pspingFileName from Internet. Make sure the Internet connection is available." -ForegroundColor Red    
            Exit -1
        }
    }
}


$command= "$($pspingLocalFullPath) -accepteula -n 1 "+$IPAddress+":"+$port 
Write-Verbose "PSPing Command line:  $command"

Write-Host "`n`nStarting to run $pspingFileName to target $IPAddress @ port $port... `n`n" -ForegroundColor Cyan

while ($killswitch -ne 0) 
{
    $timeStart = Get-Date

    #$result=test-netconnection -port $port -ComputerName $IPAddress
    #$command=$logpath+"\psping.exe -accepteula -n 1 "+$IPAddress+":"+$port 
    $o = Invoke-Expression $command

    If ($o|Select-String "Lost = 1") 
    {
        $failcount++
        $lastline="Connecting to "+$IPAddress+":"+$port+":"
        $result = $o|select-string $lastline 
        $PreciseTimeStamp=($timeStart.ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
        $line = $PreciseTimeStamp+",ERROR"+","+$IPAddress+","+$port+","+$result +","+$failcount+","+$env:COMPUTERNAME
        $line |Out-File $logfile -Encoding utf8 -Append
        Write-Host $line -Fo Red
        if ([string]::IsNullOrEmpty($aikey)) {
            Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
        } 
        else 
        {
            Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
            Send-AIEvent -piKey $aikey -pEventName "test-psping_ps1" -pCustomProperties @{RESULT="ERROR";DestIP=$ipaddress;DestPort=$port;Message=$result.ToString();FailCount=$failcount} 
        }
    }
    else 
    {
        $lastline="Connecting to "+$IPAddress+":"+$port+":"
        $result = $o|select-string $lastline
        $PreciseTimeStamp=($timeStart.ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
        $line =$PreciseTimeStamp+",SUCCESS"+","+$IPAddress+","+$port+","+$result +",0,"+$env:COMPUTERNAME
        $line |Out-File $logfile -Encoding utf8 -Append
        Write-Host $line -Fo Green
        if ([string]::IsNullOrEmpty($aikey)) {
            Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
        } 
        else 
        {
            Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
            Send-AIEvent -piKey $aikey -pEventName "test-psping_ps1" -pCustomProperties @{RESULT="SUCCESS";DestIP=$ipaddress;DestPort=$port;Message=$result.ToString();FailCount=$failcount} 
        }
        $failcount=0
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
