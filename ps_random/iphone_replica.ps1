<#
.SYNOPSIS
# this script will replicate the folder A to folder B with specific timestamp and this is for iphone folder specific 

.DESCRIPTION
This script is used to replicate source folder A to folder B
This script will read userprofile\file_replica_lastcopy.txt to get the last replica timestamp

The script will list all the files from source folder A, which are behind the last replca timestamp and copy the files to the destination folder
The script will log the complete time back to file_replica_lastcopy.txt only it perform the copy action, 
The script will log the event to Azure Application Insights and keep the result in log file folder_replica_log.txt

.PARAMETER srcfolder
Source folder to replicate

.PARAMETER dstfolder
Destination folder to replicate

.PARAMETER aikey
GUID, Instrumentation Key used by Application Insight

.EXAMPLE
replication d:\folder2 d:\folder1 12345678-1234-1234-1234-123456789012 
.\iphone_replica.ps1 -srcfolder d:\folder2 -destfolder d:\folder1 

.NOTES
Author: qliu

Date: 2024-08-20, first version
#>

# Powershell Function Write-UTCLog , 2024-04-12

Param(
    [Parameter(Mandatory=$true)][string]$srcfolder,
    [Parameter(Mandatory=$true)][string]$dstfolder,
    [string]$aikey
)

Function Write-UTCLog ([string]$message, [string]$color = "white") {
    $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    $logstamp = "[" + $logdate + "]," + $message
    Write-Host $logstamp -ForegroundColor $color
    $logstamp | Out-File "C:\Log\folder_replica_log.txt" -Append -Encoding ASCII
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

# check srcfolder and dstfolder must exists before continoue
if (-not (Test-Path $srcfolder)) {
    Write-UTCLog "Source folder $srcfolder not found" -color "red"
    exit
}

if (-not (Test-Path $dstfolder)) {
    Write-UTCLog "Destination folder $dstfolder not found" -color "red"
    exit
}

#first check if the file_replica_lastcopy.txt exists
$lastcopyfile = "$env:USERPROFILE\file_replica_lastcopy.txt"
if (-not (Test-Path $lastcopyfile)) {
    Write-UTCLog "$($env:USERPROFILE)\file_replica_lastcopy.txt not found" -color "red"
    Write-UTCLog "Create $($env:USERPROFILE)\file_replica_lastcopy.txt with default timestamp" -color "yellow"
    "1970-01-01 00:00:00" | Out-File $lastcopyfile
}
else {
    Write-UTCLog "Read $($env:USERPROFILE)\file_replica_lastcopy.txt" -color "yellow"
}

while ($true)

{
    # read the last copy timestamp
    $lastcopy = Get-Content $lastcopyfile
    Write-UTCLog "Last Copied : $lastcopy" -color "yellow"

    #use robocopy to replication video and audo
    $robocopy = "robocopy $srcfolder $dstfolder\Picture /e /xf *.mov /r:1 /w:1"
    Write-UTCLog "Robocopy : $robocopy" -color "yellow"
    Invoke-Expression $robocopy

    $robocopy = "robocopy $srcfolder $dstfolder\Video *.mov /r:1 /w:1"
    Write-UTCLog "Robocopy : $robocopy" -color "yellow"
    Invoke-Expression $robocopy

    # list all files from source folder A
    $files = Get-ChildItem $srcfolder -Recurse

    # list all files which are behind the last replica timestamp
    $files = $files | Where-Object { $_.LastWriteTime.ToUniversalTime() -gt $lastcopy }

    # sort $file in $files and find the lastest timestamp
    $lastestfile = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    #get LastAccessTimeUtc from the latest file and update file_replica_lastcopy.txt (set 1 hour early for the last sync file to avoid file sync latency problem could miss some early files)
    Write-UTCLog "Next Copy StartTime : $($lastestfile.LastAccessTimeUtc.AddHours(-1).ToString("yyyy-MM-dd HH:mm:ss"))" -color "yellow"
    $lastestfile.LastAccessTimeUtc.ToString("yyyy-MM-dd HH:mm:ss") | Out-File $lastcopyfile

    <#
    $copyflag = $false
    # copy the files to the destination folder
    foreach ($file in $files) {
        # if file extension is .mov, copy to destination\video folder , anything else copy to destination\picture folder
        if ($file.Extension -eq ".mov") {
            if (Test-Path "$dstfolder\Video\$($file.Name)") {
                Write-UTCLog "File $($file.FullName) already exist in $dstfolder\Video, skip"  "yellow"
            }
            else {
                Copy-Item $file.FullName -Destination "$dstfolder\Video" -Force            
                Write-UTCLog "File $($file.FullName) copied to $dstfolder\Video" "green"
            }
        }
        else {
            if (Test-Path "$dstfolder\Picture\$($file.Name)") {
                Write-UTCLog "File $($file.FullName) already exist in $dstfolder\Picture, skip"  "yellow"
            }
            else {                
                Copy-Item $file.FullName -Destination "$dstfolder\Picture" -Force            
                Write-UTCLog "File $($file.FullName) copied to $dstfolder\Picture" "green"
            }
        }
        $copyflag = $true
    }

    # log the complete time back to file_replica_lastcopy.txt
    if ($copyflag) {
        #get LastAccessTimeUtc from the latest file and update file_replica_lastcopy.txt (set 1 hour early for the last sync file to avoid file sync latency problem could miss some early files)
        Write-UTCLog "Next Copy StartTime : $($lastestfile.LastAccessTimeUtc.AddHours(-1).ToString("yyyy-MM-dd HH:mm:ss"))" -color "yellow"
        $lastestfile.LastAccessTimeUtc.AddHours(-1).ToString("yyyy-MM-dd HH:mm:ss") | Out-File $lastcopyfile
    }#>
    Write-UTCLog "Sleep 15 seconds" -color "yellow"
    Start-Sleep -Seconds 15 
}



