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
Starting seconds/time we will cut from the beginning. Supports seconds, MM:ss, or HH:mm:ss. Default 0

.PARAMETER lastsecs
Ending seconds/time we will cut from the ending. Supports seconds, MM:ss, or HH:mm:ss. Default 0

.PARAMETER revert
Remove the middle segment after startsecs and before lastsecs-from-end, then connect the header and trail.

.PARAMETER outputfolder
The Target folder we will save the cutted file, Default \\192.168.3.17\g$\DOWNLOADS\transfer\ffmpeg

.PARAMETER logfolder
The Log folder we will save the FFMPEG log file, Default \\192.168.3.17\g$\DOWNLOADS\ffmpeg_log\cut

.PARAMETER bitrate
set Bitrate value to control output video quality , default is 2000, (=2000Kbps)

.EXAMPLE
.\Video_Header_Trail_remove.ps1 -filename G:\DOWNLOADS\transfer\ffmpeg\video.23.1080p.HD.mp4 -outputfolder "E:\TV.Asia" -startsecs 105  -lastsecs 145 -logfolder E:\TV.Asia -bitrate 2000

.EXAMPLE
.\Video_Header_Trail_remove.ps1 -filename G:\DOWNLOADS\transfer\ffmpeg\video.23.1080p.HD.mp4 -outputfolder "E:\TV.Asia" -startsecs 00:01:45 -lastsecs 00:02:25 -logfolder E:\TV.Asia -bitrate 2000

.EXAMPLE
.\Video_Header_Trail_remove.ps1 -filename G:\DOWNLOADS\transfer\ffmpeg\video.23.1080p.HD.mp4 -outputfolder "E:\TV.Asia" -startsecs 00:10:00 -lastsecs 00:15:00 -revert -logfolder E:\TV.Asia -bitrate 2000
#>

Param (
    [Parameter(Mandatory=$true)][string]$filename,
    [string]$outputfolder="\\192.168.3.17\g$\DOWNLOADS\transfer\ffmpeg",
    [string]$logfolder="\\192.168.3.17\g$\DOWNLOADS\ffmpeg_log\cut",
    [ValidateSet("h264_qsv","h264_nvenc","h264_amf","hevc_qsv","hevc_nvenc","hevc_amf")][string]$gpu="hevc_qsv",
    [int]$crf, #introduct crf if crf is specified, crf will override bitrate 
    #Range	0-51
    #H.264	Recommended CRF Range 18 28
    #H.265	Recommended CRF Range 24 30
    [int]$bitrate, # in Kbps
    [string]$startsecs="0",
    [string]$lastsecs="0",
    [switch]$revert
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
            If( $null -ne $index )
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

Function Convert-CutTimeToSeconds ([string]$value, [string]$parameterName)
{
    if ([string]::IsNullOrWhiteSpace($value))
    {
        return 0
    }

    $timeValue = $value.Trim()
    $seconds = 0.0

    if ([double]::TryParse($timeValue, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$seconds))
    {
        if ($seconds -lt 0) { Write-UTCLog "$parameterName cannot be negative: $value" "Red"; exit }
        return $seconds
    }

    if ($timeValue -match '^\d{1,2}:\d{2}$')
    {
        $parts = $timeValue.Split(":")
        $minutes = [int]$parts[0]
        $secondsPart = [int]$parts[1]

        if ($secondsPart -ge 60)
        {
            Write-UTCLog "$parameterName must use MM:ss format with seconds less than 60: $value" "Red"
            exit
        }

        return ([TimeSpan]::New(0, $minutes, $secondsPart)).TotalSeconds
    }

    if ($timeValue -match '^\d{1,2}:\d{2}:\d{2}$')
    {
        $parts = $timeValue.Split(":")
        $hours = [int]$parts[0]
        $minutes = [int]$parts[1]
        $secondsPart = [int]$parts[2]

        if (($minutes -ge 60) -or ($secondsPart -ge 60))
        {
            Write-UTCLog "$parameterName must use HH:mm:ss format with minutes and seconds less than 60: $value" "Red"
            exit
        }

        return ([TimeSpan]::New($hours, $minutes, $secondsPart)).TotalSeconds
    }

    Write-UTCLog "$parameterName must be seconds, MM:ss, or HH:mm:ss format: $value" "Red"
    exit
}

Function Format-CutTime ([double]$seconds)
{
    return ([TimeSpan]::FromSeconds($seconds)).ToString("hh\:mm\:ss")
}

If ((Test-Path $filename) -and (Test-Path $outputfolder))
{


    #use ffprobe to get video duration
    $videoduration=ffprobe "$filename" -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -v error
    $videodurationSeconds = [double]::Parse($videoduration, [System.Globalization.CultureInfo]::InvariantCulture)
    # convert video duration from seconds to hh:mm:ss
    $VideoLength = Format-CutTime $videodurationSeconds

    #two steps to get video bitrate and audio bitrate separately
    #use stream bitrate as primary choice if that is available, for mkv file, audio stream bitrate may not available, we use hard code 96kbps for audio bitrate
    try 
    { 
        $videobitrate=[int]((ffprobe "$filename" -show_entries stream=bit_rate -select_streams v:0 -of default=noprint_wrappers=1:nokey=1 -v error)/1000) 
    }
    catch
    {    
        $videobitrate=0 
    }

    if ($videobitrate -eq 0) 
    {
        #Use bit_rate of the file for Video Bitrate
        $videobitrate=[int]((ffprobe "$filename" -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 -v error)/1000)
    }

    try {
        $audiobitrate=[int]((ffprobe "$filename" -show_entries stream=bit_rate -select_streams a:0 -of default=noprint_wrappers=1:nokey=1 -v error)/1000)
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
    
    $startsecsValue = Convert-CutTimeToSeconds $startsecs "startsecs"
    $lastsecsValue = Convert-CutTimeToSeconds $lastsecs "lastsecs"
    $endsecs = $videodurationSeconds - $lastsecsValue

    if (($startsecsValue -ge 86400) -or ($lastsecsValue -ge 86400) -or ($endsecs -ge 86400)) {Write-UTCLog "Start / Last / End time cannot be greater than 86400 seconds (1 day)" "Red"; exit}

    #Error handling
    if ($startsecsValue -ge $videodurationSeconds) { Write-UTCLog "Cut Start time cannot be greater than Video Length!" "red"; exit}
    if ($lastsecsValue -ge $videodurationSeconds) { Write-UTCLog "Cut Last time cannot be greater than Video Length!" "red"; exit}
    if ($endsecs -gt $videodurationSeconds) { Write-UTCLog "Cut End time cannot be greater than Video Length!" "red"; exit}
    if ($endsecs -le $startsecsValue) { Write-UTCLog "Cut End time must be greater than Cut Start time!" "red"; exit}
    if (($startsecsValue + $lastsecsValue) -ge $videodurationSeconds){ Write-UTCLog "Cut Start + Last time cannot be greater than Video Length!" "red"; exit}
    if ($revert -and ($startsecsValue -eq 0) -and ($endsecs -eq $videodurationSeconds)) { Write-UTCLog "Revert cut would remove the entire video." "red"; exit}

    $truename=$filename.split("\")[$filename.split("\").count-1]
    # replace truename file extension with mp4
    $truename=$truename.TrimEnd($truename.split(".")[$truename.split(".").count-1])+"mp4"
    # create output file name with path
    $outputfile=$outputfolder.TrimEnd("\")+"\"+$truename
    $logfile=$logfolder.TrimEnd("\")+"\"+$truename.TrimEnd($truename.split(".")[$truename.split(".").count-1])+"cut.log" # remove file extension and append "cut.log"

    Write-UTCLog "Source : ($($fileName)) : $($VideoLength) - $($videoduration) s"  "Green"
    Write-UTCLog " - Video Bitrate : $($videobitrate) K and bitrate(used for encoding) : $($bitrate) K"
    Write-UTCLog " - Audio Bitrate : $($audiobitrate) K and bitrate(used for encoding) : $($bitrate_audio) K"
    if ($revert)
    {
        Write-UTCLog " Revert cut middle segment : $($startsecsValue) - $($endsecs), keep tail duration: $($lastsecsValue)"  "Green"
    }
    else
    {
        Write-UTCLog " Cut from the begin : $($startsecsValue)  -   Cut from the end : $($lastsecsValue)"  "Green"
    }

    $startTimestamp=Format-CutTime $startsecsValue
    $endTimestamp = Format-CutTime $endsecs
    Write-UTCLog "Target : ($($outputfile)): $($startTimestamp)($($startsecsValue)) - $($endTimestamp)($($endsecs)), Bitrate: $($bitrate)k, Revert: $($revert.IsPresent)"  "Yellow"
    Write-UTCLog "GPU: $($gpu)" "Green"

    #direct cut without encoding, this will cause a few seconds black screen for target file. 
    # change to nv12 and enable support for all gpu brand intel_qsv , nvidia_nvenc, amd_amf
    # crf overrides bitrate when it is specified.
    $videoEncodeOptions = "-c:v $($gpu) -b:v $($bitrate)k"
    if ($PSBoundParameters.ContainsKey('crf'))
    {
        $videoEncodeOptions = "-c:v $($gpu) -crf $($crf) -preset slow"
    }

    if ($revert -and ($startsecsValue -gt 0) -and ($endsecs -lt $videodurationSeconds))
    {
        $audioStream=ffprobe "$filename" -show_entries stream=index -select_streams a:0 -of default=noprint_wrappers=1:nokey=1 -v error
        if ([string]::IsNullOrWhiteSpace($audioStream))
        {
            $filterComplex = "[0:v]trim=start=0:end=$($startsecsValue),setpts=PTS-STARTPTS[v0];[0:v]trim=start=$($endsecs):end=$($videodurationSeconds),setpts=PTS-STARTPTS[v1];[v0][v1]concat=n=2:v=1:a=0,scale=1920:-2,format=nv12[vout]"
            $ffcmd="ffmpeg.exe -y -i ""$($filename)"" -filter_complex ""$($filterComplex)"" -map ""[vout]"" $($videoEncodeOptions) -map_chapters 0 -map_metadata 0 -f mp4 -threads 0 ""$($outputfile)"" 2> ""$($logfile)"""
        }
        else
        {
            $filterComplex = "[0:v]trim=start=0:end=$($startsecsValue),setpts=PTS-STARTPTS[v0];[0:a]atrim=start=0:end=$($startsecsValue),asetpts=PTS-STARTPTS[a0];[0:v]trim=start=$($endsecs):end=$($videodurationSeconds),setpts=PTS-STARTPTS[v1];[0:a]atrim=start=$($endsecs):end=$($videodurationSeconds),asetpts=PTS-STARTPTS[a1];[v0][a0][v1][a1]concat=n=2:v=1:a=1[vcat][acat];[vcat]scale=1920:-2,format=nv12[vout]"
            $ffcmd="ffmpeg.exe -y -i ""$($filename)"" -filter_complex ""$($filterComplex)"" -map ""[vout]"" -map ""[acat]"" $($videoEncodeOptions) -c:a aac -b:a $($bitrate_audio)k -map_chapters 0 -map_metadata 0 -f mp4 -threads 0 ""$($outputfile)"" 2> ""$($logfile)"""
        }
    }
    else
    {
        if ($revert -and ($startsecsValue -eq 0))
        {
            $startTimestamp = Format-CutTime $endsecs
            $endTimestamp = Format-CutTime $videodurationSeconds
        }
        elseif ($revert -and ($endsecs -eq $videodurationSeconds))
        {
            $startTimestamp = Format-CutTime 0
            $endTimestamp = Format-CutTime $startsecsValue
        }

        $ffcmd="ffmpeg.exe -y -i ""$($filename)"" -ss $($startTimestamp).000 -to $($endTimestamp).000  $($videoEncodeOptions) -pix_fmt nv12 -vf ""scale=1920:-2"" -map 0:v:0? -map 0:a:0? -c:a aac -b:a $($bitrate_audio)k -map -0:s -map_chapters 0 -map_metadata 0 -f mp4 -threads 0 ""$($outputfile)"" 2> ""$($logfile)"""
    }
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
