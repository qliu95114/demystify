# this script scan all source folder with given file naming pattern and convert all video to target folder with same file name. 

Param (
    [string]$srcpath=$((Get-Location).path),
    [string]$destpath="G:\DOWNLOADS\transfer\ffmpeg",
    [string]$filepattern="*.mp4",
    [string]$logfolder="G:\DOWNLOADS\ffmpeg_log",
	[int]$mychoice=9999
)

#Send-UdpDatagram -EndPoint $Endpoint -Port $port -Message "test.mymetric:0|c"      
Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

function Read-HostWithDelay {
  param([Parameter(Mandatory=$true)][int]$Delay, [string]$Prompt, [Switch]$AsSecureString=$False)
  [int]$CSecDelayed = 0
  do {
    [bool]$BReady = $host.UI.RawUI.KeyAvailable
    [Threading.Thread]::Sleep(1000)
  } while (!$BReady -and ($CSecDelayed++ -lt $Delay))
  if ($BReady -and $Prompt) { Read-Host $Prompt -AsSecureString:$AsSecureString }
  # No, Read-Host will not in fact handle null parameter binding (-Prompt:$Prompt) properly. Who knows why not.
  elseif ($BReady) { Read-Host -AsSecureString:$AsSecureString }      
}

function FFMpegCommand (
    [string]$srcfile,
    [string]$dstfile,
    [string]$logfile,
    [string]$profile,
    [string]$prefix
)
{
    $ffcmd="ffmpeg.exe $($prefix) -i ""$($srcfile)"" $($profile) ""$($dstfile)"" 2> ""$($logfile)"""
    Write-UTCLog "Command to execute: $($ffcmd)"
    Write-UTCLog "Begining MP4 FileConvert $($srcfile) to $($dstfile)" "Green"
    $st=Get-date
    Invoke-Expression $ffcmd
    $et=Get-date
    Write-UTCLog "Complete MP4 FileConvert $($dstfile) , time : $(($et-$st).TotalSeconds) (secs)" "Yellow"
}


$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

Write-UTCLog "Script start @ $($PSScriptRoot)"
Write-UTCLog "Searching FileName : $($filepattern)"
Write-UTCLog "Source Folder: $($srcpath)"
$oldvids = Get-ChildItem "$($srcpath)\$($filepattern)"

if (Test-path $destpath) 
{
    Write-UTCLog "Destination Folder: $($destpath)"
} else 
{   
    mkdir $destpath
    Write-UTCLog "Destination Folder: $($destpath) does not exsit, creating..." "Yellow"
}

if (Test-Path "$($PSScriptRoot)\ffmpeg_profile.json") {

    $profilelist=(get-content "$($PSScriptRoot)\ffmpeg_profile.json")|convertfrom-Json
    for ($i=0;$i -lt $profilelist.count;$i++)
    {
        Write-Host "$($i) : $($profilelist[$i].Suffix)"
    }
	if (($mychoice -eq 9999) -or ($mychoice -gt $profilelist.count))
	{
		$choice=Read-Host "make your choice (0 - $($profilelist.count-1))" 
	}
	else
	{
		$choice=$mychoice
	}
    Write-Host "Your select $($choice) : $($profilelist[$choice].Suffix)"

    foreach ($oldvid in $oldvids) {
    $newvid = $oldvid.basename+".mp4"
    $logfile= $oldvid.basename+"_"+$profilelist[$choice].Suffix+"_ffmpeg.txt"
    if (Test-Path "$($destpath)\$($newvid)") 
        {if ((Read-Host "Destination File $($destpath)\$($newvid) Exist! Do you want to delete and continue [Y/N]").tolower() -eq "y") 
            {
                Remove-Item "$($destpath)\$($newvid)" -Force
                write-UTCLog "Destination File $($destpath)\$($newvid) deleted" "Yellow"
                FFMpegCommand -srcfile "$($oldvid.FullName)" -dstfile "$($destpath)\$($newvid)" -logfile "$($logfolder)\$($logfile)" -profile "$($profilelist[$choice].commandline)" -prefix "$($profilelist[$choice].prefix)"
            }
        else{
                Write-UTCLog "Skip convert the file as destination file exists" "Yellow"
        }
    }
    else
    {
        FFMpegCommand -srcfile "$($oldvid.FullName)" -dstfile "$($destpath)\$($newvid)" -logfile "$($logfolder)\$($logfile)" -profile "$($profilelist[$choice].commandline)" -prefix "$($profilelist[$choice].prefix)"
    }}
    Write-UTCLog "File Covert complete, check Destination Folder: $($destpath)"
}
else
{
    Write-UTCLog "Cannot file $($PSScriptRoot)\ffmpeg_profile.json" "Red"
    exit
}
