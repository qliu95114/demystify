
<#
co-authoer: qliu
Usage: Test-sql.ps1  -server -database -username -password -query
Output: build a TEXT output Warp on top of Invoke-sqlcmd, 

Version: 1.0.20231215.1702

2020-12-15, first version

#>

Param (
    [Parameter(Mandatory=$true, Position=0)][string]$server,
    [Parameter(Mandatory=$true, Position=1)][string]$Database,
	[Parameter(Mandatory=$true, Position=2)][string]$Username,
	[Parameter(Mandatory=$true, Position=3)][string]$password,
	[string]$Query="select TOP 5 name, object_id, schema_id, create_date, modify_date from sys.all_views",
	[int]$intervalinMS=5000,  #interval is -Milliseconds,
    [int]$timeout=5,
	[string]$logpath=$env:temp,
    [switch]$verboselog,
    [string]$containerid,
    [guid]$aikey
)

Function Write-UTCLog ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}


# Powershell Function Send-AIEvent , 2023-04-08
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
$logfile= Join-Path $logpath $($env:COMPUTERNAME+"_Testsql_$($server.split('.')[0])_$($Database).log")
$scriptname=$MyInvocation.MyCommand.Name

# check if SQL module is installed, if not, install it.
if ((Get-Module -ListAvailable -Name SqlServer).count -gt 0) {
	Write-UTCLog "SqlServer module is installed" "Gray"
} else {
	Write-UTCLog "SqlServer module is not installed, installing..." "Yellow"
	Install-Module -Name SqlServer -Force
}	

# if containerid is empty or null, try to get it from goalstate
if ([string]::IsNullOrEmpty($containerid)) { 
    Write-UTCLog "ContainerId is empty, try to get it from goalstate" -color "Yellow"
    $containerid=([xml](c:\windows\system32\curl --connect-timeout 0.2 "http://168.63.129.16/machine?comp=goalstate" -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A """")).GoalState.Container.ContainerId
}

Write-UTCLog "Log File : $($logfile)" -color "Cyan"
Write-UTCLog "Running Invoke-sqlcmd test, press CTRL + C to stop" -color "Cyan"
Write-UTCLog "Server : $($server)     Database : $($Database)   Username : $($Username)   Password : ***** " -color "gray"
Write-UTCLog "Query  : '$($Query)'" -color "gray"

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

$headline="TIMESTAMP,COMPUTERNAME,SQLSERVER,DATABASE,RESULT,FailCount,RecordCount,containerid"
$headline | Out-File $logfile -Encoding utf8 -Append

while ($killswitch -ne 0) 
{
    $timeStart = Get-Date
    try 
        {
            $strState = "Success"
            $result = invoke-sqlcmd -ServerInstance $server -database $Database -Username $Username -Password $password -Query $Query -QueryTimeout $timeout 
            $result = "$($timeStart.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')),$($env:COMPUTERNAME),$($Server),$($Database),OK,0,$($result.count),$($containerid)"
            Write-Host $result -Fo "Cyan"
            $result |Out-File $logfile -Encoding utf8 -Append
            
            if ([string]::IsNullOrEmpty($aikey)) {
                if ($verboselog) {Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"}
            } 
            else 
            {
                if ($verboselog) {Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"}
                Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{result="OK";Server=$server;failcount="0";database=$database.tostring();details=$($result.count);containerid=$containerid} 
            }
        
            if($verboselog)
            {
                $result
                $result | Out-File $logfile -Encoding utf8 -Append
            }    
        }
        catch 
        {
            $failcount++
            $strState = "ERROR"
            $result = "$((get-date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')),$($env:COMPUTERNAME),$($Server),$($Database),$($strState),$($failcount),$($_),$($containerid)"
            Write-Host $result -Fo "Red"
            $result |Out-File $logfile -Encoding utf8 -Append
            $_
            
            if ([string]::IsNullOrEmpty($aikey)) {
                Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
            } 
            else 
            {
                Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
                Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{result=$strState.tostring();Server=$server;failcount=$failcount.tostring();database=$database.tostring();details=$_;containerid=$containerid} 
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

