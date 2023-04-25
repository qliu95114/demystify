# this script scan all *.wav file in the source folder and convert all *.wav to MP3.

Param (
    [string]$srcpath="d:\temp",
    [string]$destpath="d:\temp\mp3",
    [string]$filepattern="*.wav",
	[int]$mychoice=9999
)

# a function to write log with UTC time stamp
Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

function FFMpegCommand (
    [string]$srcfile,
    [string]$dstfile,
    [string]$logfile,
    [string]$profile
)
{
    $ffcmd="ffmpeg.exe -i ""$($srcfile)"" $($profile) ""$($dstfile)"""# 2> ""$($logfile)"""
    Write-UTCLog "Command to execute: $($ffcmd)"
    Write-UTCLog "Begining MP3 FileConvert $($srcfile) to $($dstfile)" "Green"
    $st=Get-date
    iex $ffcmd
    $et=Get-date
    Write-UTCLog "Complete MP3 FileConvert $($dstfile) , time : $(($et-$st).TotalSeconds) (secs)" "Yellow"
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

$profile= " -vn -ar 44100 -ac 2 -b:a 256k "

foreach ($oldvid in $oldvids) 
{
    $newvid = $oldvid.basename+".mp3"
    $logfile= $oldvid.basename+"_"+$profile+"_ffmpeg.txt"
    if (Test-Path "$($destpath)\$($newvid)") 
        {if ((Read-Host "Destination File $($destpath)\$($newvid) Exist! Do you want to delete and continue [Y/N]").tolower() -eq "y") 
            {
                del "$($destpath)\$($newvid)" 
                write-UTCLog "Destination File $($destpath)\$($newvid) deleted" "Yellow"
                FFMpegCommand -srcfile "$($oldvid.FullName)" -dstfile "$($destpath)\$($newvid)" -logfile "$($destpath)\$($logfile)" -profile "$($profile)"
            }
        else{
                write-UTCLog "Skip convert the file as destination file exists" "Yellow"
        }
    }
    else
    {
        FFMpegCommand -srcfile "$($oldvid.FullName)" -dstfile "$($destpath)\$($newvid)" -logfile "$($destpath)\$($logfile)" -profile "$($profile)" 
    }
}
Write-UTCLog "File Covert complete, check Destination Folder: $($destpath)"
