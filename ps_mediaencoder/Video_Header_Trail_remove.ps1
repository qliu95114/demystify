#requires -version 3
<#
    Get the named extended property(s) from the file or all available properties
    With code from https://rkeithhill.wordpress.com/2005/12/10/msh-get-extended-properties-of-a-file/
    @guyrleech 17/12/2019
#>

<#
.SYNOPSIS
Use FFMPG to remove header/trail of an video file 

.DESCRIPTION
Use FFMPG to remove header/trail of an video file 

.PARAMETER filename
The name of the file to be converted, please include full path of the file , wildchar is not supported. 

.PARAMETER startsecs
Starting Seconds we will cut from the beginning, Default 0

.PARAMETER lastsecs
Ending Seconds we will cut from the ending, Default 0

.PARAMETER outputfolder
The Target folder we will save the cutted file, Default \\192.168.3.17\g$\DOWNLOADS\transfer\ffmpeg

.PARAMETER logfolder
The Log folder we will save the FFMPEG log file, Default \\192.168.3.17\g$\DOWNLOADS\ffmpeg_log\cut

.PARAMETER bitrate
set Bitrate value to control output video quality , default is 2000, (=2000Kbps)

.EXAMPLE
.\Video_Header_Trail_remove.ps1 -filename G:\DOWNLOADS\transfer\ffmpeg\video.23.1080p.HD.mp4 -outputfolder "E:\TV.Asia" -startsecs 105  -lastsecs 145 -logfolder E:\TV.Asia -bitrate 2000
#>

Param (
    [Parameter(Mandatory=$true)][string]$filename,
    [string]$outputfolder="\\192.168.3.17\g$\DOWNLOADS\transfer\ffmpeg",
    [string]$logfolder="\\192.168.3.17\g$\DOWNLOADS\ffmpeg_log\cut",
    [ValidateSet("h264_nvenc","h264_amf")][string]$gpu="h264_amf",
    [int]$bitrate, # in Kbps
    [int]$startsecs=0,
    [int]$lastsecs=0
)

# function is deprecated as we use ffprobe to get video duration that support more file format
Function Get-ExtendedProperties
{
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$true,HelpMessage='File name to retrieve properties of')]
        [ValidateScript({Test-Path -Path $_})]
        [string]$fileName ,
        [AllowNull()]
        [string[]]$properties
    )

    [hashtable]$propertiesToIndex = @{}
    ## need to use absolute paths
    $fileName = Resolve-Path -Path $fileName | Select-Object -ExpandProperty Path
    $shellApp = New-Object -Com shell.application
    $myFolder = $shellApp.Namespace( (Split-Path -Path $fileName -Parent) )
    $myFile = $myFolder.Items().Item( (Split-Path -Path $fileName -Leaf) )

    0..500 | ForEach-Object `
    {
        If( $key = $myFolder.GetDetailsOf( $null , $_ ) )
        {
            Try
            {
                $propertiesToIndex.Add( $key , $_ )
            }
            Catch
            {
            }
        }
    }

    Write-Verbose "Got $($propertiesToIndex.Count) unique property names"

    If( ! $PSBoundParameters[ 'properties' ] -or ! $properties -or ! $properties.Count )
    {
        ForEach( $property in $propertiesToIndex.GetEnumerator() )
        {
            $thisProperty = $myFolder.GetDetailsOf( $myFile , $property.Value )
            If( ! [string]::IsNullOrEmpty( $thisProperty ) )
            {
                [pscustomobject]@{ 
                    'Property' = $property.Name
                    'Value' = $thisProperty
                }
            }
        }
    }
    Else
    {
        ForEach( $property in $properties )
        {
            $index = $propertiesToIndex[ $property ]
            If( $index -ne $null )
            {
                $myFolder.GetDetailsOf( $myFile , $index -as [int] )
            }
            Else
            {
                Write-Warning "No index for property `"$property`""
            }
        }
    }
}
Function Write-UTCLog ([string]$message,[string]$color="green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

if (($startsecs -ge 86400) -or ($lastsecs -ge 86400)) {Write-UTCLog "Start / Last Seconds cannot be greater than 86400 (1day)" "Red"; exit}

If ((Test-Path $filename) -and (Test-Path $outputfolder))
{
    #$VideoLength=((Get-ExtendedProperties  $filename)| where {$_.Property -eq "Length"}).Value
    #$videoduration=[int]$VideoLength.split(":")[0]*3600+[int]$VideoLength.split(":")[1]*60+[int]$VideoLength.split(":")[2]

    #use ffprobe to get video duration
    $videoduration=ffprobe ""$($filename)"" -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -v error
    # convert video duration from seconds to hh:mm:ss
    $VideoLength = "{0:hh\:mm\:ss}" -f (New-Object System.TimeSpan 0,0,$videoduration)

    #two steps to get video bitrate and audio bitrate separately
    #use stream bitrate as primary choice if that is available, for mkv file, audio stream bitrate may not available, we use hard code 96kbps for audio bitrate
    try 
    { 
        $videobitrate=[int]((ffprobe ""$($filename)"" -show_entries stream=bit_rate -select_streams v:0 -of default=noprint_wrappers=1:nokey=1 -v error)/1000) 
    }
    catch
    {    
        $videobitrate=0 
    }

    if ($videobitrate -eq 0) 
    {
        #Use bit_rate of the file for Video Bitrate
        $videobitrate=[int]((ffprobe ""$($filename)"" -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 -v error)/1000)
    }

    try {
        $audiobitrate=[int]((ffprobe ""$($filename)"" -show_entries stream=bit_rate -select_streams a:0 -of default=noprint_wrappers=1:nokey=1 -v error)/1000)
        # if $audiobitrate is large than 96 and use 96kbps as default    
        if ($audiobitrate -gt 96) {$bitrate_audio=96} else {$bitrate_audio=$audiobitrate}
    }
    catch {
        $audiobitrate=0
        $bitrate_audio=96
    }

    if ($bitrate -eq 0)
    {
        $bitrate=$videobitrate
    } 
    
    #Error handling
    if ($startsecs -ge $videoduration) { Write-UTCLog "Cut Start seconds cannot be greater than Vidoe Length!" "red"; exit}
    if ($lastsecs -ge $videoduration) { Write-UTCLog "Cut Last seconds cannot ber greater than Vidoe Length!" "red"; exit}
    if (($startsecs+$lastsecs) -ge $videoduration){ Write-UTCLog "Cut Start + Last seconds cannot be greater than Vidoe Length!" "red"; exit}

    $truename=$filename.split("\")[$filename.split("\").count-1]
    # replace truename file extension with mp4
    $truename=$truename.TrimEnd($truename.split(".")[$truename.split(".").count-1])+"mp4"
    # create output file name with path
    $outputfile=$outputfolder.TrimEnd("\")+"\"+$truename
    $logfile=$logfolder.TrimEnd("\")+"\"+$truename.TrimEnd($truename.split(".")[$truename.split(".").count-1])+"cut.log" # remove file extension and append "cut.log"

    Write-UTCLog "Source : ($($fileName)) : $($VideoLength) - $($videoduration) s"  "Green"
    Write-UTCLog " - Video Bitrate : $($videobitrate) K and bitrate(used for encoding) : $($bitrate) K"
    Write-UTCLog " - Audio Bitrate : $($audiobitrate) K and bitrate(used for encoding) : $($bitrate_audio) K"
    Write-UTCLog " Cut from the begin : $($startsecs)  -   Cut from the end : $($lastsecs)"  "Green"

    $endsecs = $videoduration-$lastsecs
    $starttime=([timespan]::fromseconds($startsecs)).ToString().split(".")[0]
    $endtime = ([timespan]::fromseconds($endsecs)).ToString().split(".")[0]
    Write-UTCLog "Target : ($($outputfile)): $($starttime)($($startsecs)) - $($endtime)($($endsecs)), Bitrate: $($bitrate)k"  "Yellow"
    Write-UTCLog "GPU: $($gpu)" "Green"

    #direct cut without encoding, this will cause a few seconds black screen for target file. 
    #$ffcmd="ffmpeg.exe -y -i ""$($filename)"" -ss $($starttime).000 -to $($endtime).000  -c:v copy -map 0:v:0? -c:a copy -map 0:a? -c:s copy -map 0:s? -map_chapters 0 -map_metadata 0 -f mp4 -threads 0 ""$($outputfile)"" 2> ""$($logfile)"""
    $ffcmd="ffmpeg.exe -y -i ""$($filename)"" -ss $($starttime).000 -to $($endtime).000  -c:v $($gpu) -b:v $($bitrate)k -pix_fmt yuv420p -vf ""scale=1920:-2"" -map 0:v:0? -c:a copy -map 0:1 -c:a aac -b:a $($bitrate_audio)k -c:s mov_text -map 0:s? -map_chapters 0 -map_metadata 0 -f mp4 -threads 0 ""$($outputfile)"" 2> ""$($logfile)"""
    Write-UTCLog "CMD: $($ffcmd)" "Green"
    Write-UTCLog "Cut/Encode Start : $($filename) " "Green"
    $st=Get-date;  Invoke-Expression $ffcmd; $et=Get-date
    Write-UTCLog "Cut/Encode Complete : $($outputfile)" "Cyan"
    Write-UTCLog "Total time : $(($et-$st).TotalSeconds) (secs)" "Cyan"
}
else
{
    Write-UTCLog "File $($filename) or Folder $($outputfolder) does not exist, please recheck"  "Red"
}

