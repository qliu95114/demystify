#Requires -Version 5.1

<#
    Get the named extended property(s) from the file or all available properties
    With code from https://rkeithhill.wordpress.com/2005/12/10/msh-get-extended-properties-of-a-file/
    @guyrleech 17/12/2019
#>

<#
.SYNOPSIS
Use FFMPG to remove header/trail of an video file 

.DESCRIPTION
Use FFMPG to remove header/trail of an video file.
Embedded text subtitles are selected, clipped, time-shifted, and merged into the output MP4.
Supports Windows PowerShell 5.1 and PowerShell 7+ on Windows.

.PARAMETER filename
The name of the file to be converted, please include full path of the file , wildchar is not supported. 

.PARAMETER startsecs
Starting seconds/time we will cut from the beginning. Supports seconds, MM:ss, or HH:mm:ss. Default 0

.PARAMETER lastsecs
Ending seconds/time we will cut from the ending. Supports seconds, MM:ss, or HH:mm:ss. Default 0

.PARAMETER revert
Remove the middle segment after startsecs and before lastsecs-from-end, then connect the header and trail.

.PARAMETER SubtitleStreamIndex
Absolute ffprobe stream index to retain. Default -1 automatically selects a text subtitle stream.

.PARAMETER SubtitleLanguage
Preferred language for automatic subtitle selection. Default chi (Chinese).

.PARAMETER SkipSubtitles
Discard subtitles instead of cutting and retaining them. Image-based subtitles are not supported.

.PARAMETER AudioStreamIndex
Absolute ffprobe audio stream index. Explicit -1 enables automatic selection.
Without audio-selection options, the first audio track is retained.

.PARAMETER AudioCodec
Preferred source audio codec for automatic selection (default aac). Output remains AAC.

.PARAMETER AudioChannels
Preferred source channel count for automatic selection (default 2). Does not downmix.

.PARAMETER AudioLanguage
Preferred source language tag for automatic selection (default no language preference).
Preferences are scored: codec 100, channels 50, language 30, bitrate up to 10.

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
    [switch]$revert,
    [ValidateRange(-1, [int]::MaxValue)][int]$SubtitleStreamIndex = -1,
    [string]$SubtitleLanguage = "chi",
    [switch]$SkipSubtitles,
    [ValidateRange(-1, [int]::MaxValue)][int]$AudioStreamIndex = -1,
    [ValidateNotNullOrEmpty()][string]$AudioCodec = "aac",
    [ValidateRange(1, [int]::MaxValue)][int]$AudioChannels = 2,
    [string]$AudioLanguage = ""
)

. (Join-Path $PSScriptRoot "help_class.ps1")

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
    return ([TimeSpan]::FromSeconds($seconds)).ToString("hh\:mm\:ss\.fff")
}

Function Select-CutAudioStream (
    [array]$streams, [int]$streamIndex = -1, [switch]$autoSelect,
    [string]$codec = "aac", [int]$channels = 2, [string]$language = ""
)
{
    $audioStreams = @($streams | Where-Object { $_.codec_type -eq "audio" })
    if ($streamIndex -ge 0)
    {
        $selected = $audioStreams | Where-Object { $_.index -eq $streamIndex }
        if (!$selected) { throw "Stream $streamIndex is not an audio stream." }
        return $selected
    }
    if ($autoSelect)
    {
        $bestIndex = Find-BestAudioStream -Streams $audioStreams -PreferredCodec $codec -PreferredChannels $channels -PreferredLanguage $language
        return ($audioStreams | Where-Object { $_.index -eq $bestIndex })
    }
    return ($audioStreams | Select-Object -First 1)
}

Function Invoke-CutFFmpeg ([string[]]$arguments, [string]$logPath, [string]$description)
{
    $process = Invoke-FFmpegWithLogging -Arguments (@("-nostdin", "-y") + $arguments) -LogFile $logPath -Description $description
    if ($process.ExitCode -ne 0)
    {
        $details = Get-Content -LiteralPath $logPath -Tail 12 -ErrorAction Stop | Out-String
        throw "$description failed (FFmpeg exit code $($process.ExitCode)). See $logPath`n$details"
    }
}

Function Assert-CutVideo ([string]$path, [string]$logPath)
{
    $probe = & ffprobe -v error -select_streams v:0 -show_entries stream=codec_type,duration -of json "$path"
    if ($LASTEXITCODE -ne 0) { throw "Cannot read encoded video: $path. See $logPath" }
    $video = (($probe -join "`n") | ConvertFrom-Json).streams | Select-Object -First 1
    $duration = 0.0
    if (!$video -or ![double]::TryParse($video.duration, [System.Globalization.NumberStyles]::Float,
        [cultureinfo]::InvariantCulture, [ref]$duration) -or $duration -le 0)
    {
        throw "FFmpeg produced no video frames in $path despite reporting success. See $logPath"
    }
}

Function Convert-CutSubtitle ([string]$content, [array]$ranges)
{
    $cues = @(
        foreach ($block in [regex]::Split($content.Trim(), '\r?\n\s*\r?\n'))
        {
            if ([string]::IsNullOrWhiteSpace($block)) { continue }
            $match = [regex]::Match($block, '(?s)^\d+\r?\n(?<start>\d{2}:\d{2}:\d{2},\d{3}) --> (?<end>\d{2}:\d{2}:\d{2},\d{3})[^\r\n]*\r?\n(?<text>.+)$')
            if (!$match.Success) { throw "Invalid SRT cue in extracted subtitle: $block" }
            [pscustomobject]@{
                Start = [TimeSpan]::ParseExact($match.Groups['start'].Value, 'hh\:mm\:ss\,fff', [cultureinfo]::InvariantCulture).TotalMilliseconds
                End = [TimeSpan]::ParseExact($match.Groups['end'].Value, 'hh\:mm\:ss\,fff', [cultureinfo]::InvariantCulture).TotalMilliseconds
                Text = $match.Groups['text'].Value
            }
        }
    )

    $result = [System.Text.StringBuilder]::new()
    $index = 0
    $offset = 0.0
    foreach ($range in $ranges)
    {
        $rangeStart = [math]::Round($range.Start * 1000)
        $rangeEnd = [math]::Round($range.End * 1000)
        foreach ($cue in $cues)
        {
            # Intersect each cue with each retained segment, including cues spanning a cut.
            $start = [math]::Max($cue.Start, $rangeStart)
            $end = [math]::Min($cue.End, $rangeEnd)
            if ($end -le $start) { continue }
            $index++
            $startTime = [TimeSpan]::FromMilliseconds($start - $rangeStart + $offset).ToString('hh\:mm\:ss\,fff')
            $endTime = [TimeSpan]::FromMilliseconds($end - $rangeStart + $offset).ToString('hh\:mm\:ss\,fff')
            [void]$result.AppendLine("$index")
            [void]$result.AppendLine("$startTime --> $endTime")
            [void]$result.AppendLine($cue.Text)
            [void]$result.AppendLine()
        }
        $offset += $rangeEnd - $rangeStart
    }
    return $result.ToString()
}

Function Add-CutSubtitle (
    [string]$sourceFile, [string]$targetFile, [string]$subtitleLog,
    [array]$ranges, [int]$streamIndex, [string]$preferredLanguage
)
{
    $streams = @(Get-StreamInfo -FilePath $sourceFile | Where-Object { $_.codec_type -eq "subtitle" })
    $textCodecs = @("subrip", "srt", "ass", "ssa", "mov_text", "webvtt", "text")
    if ($streamIndex -ge 0)
    {
        $selected = $streams | Where-Object { $_.index -eq $streamIndex }
        if (!$selected) { throw "Stream $streamIndex is not a subtitle stream." }
        if ($selected.codec_name -notin $textCodecs) { throw "Subtitle codec '$($selected.codec_name)' cannot be converted to text without OCR." }
    }
    else
    {
        $textStreams = @($streams | Where-Object { $_.codec_name -in $textCodecs })
        $bestIndex = Find-BestSubtitleStream -Streams $textStreams -PreferredLanguage $preferredLanguage
        $selected = $textStreams | Where-Object { $_.index -eq $bestIndex }
        if (!$selected)
        {
            Write-UTCLog "No supported text subtitle stream found; output has no subtitles (bitmap subtitles require OCR)." "Yellow"
            return
        }
    }

    Write-UTCLog "Cutting subtitle stream $($selected.index) ($($selected.codec_name), $($selected.tags.language))"
    $tempFolder = Join-Path ([System.IO.Path]::GetDirectoryName($targetFile)) (".cut-subtitles-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempFolder -ErrorAction Stop | Out-Null
    try
    {
        $extractedFile = Join-Path $tempFolder "original.srt"
        $shiftedFile = Join-Path $tempFolder "cut.srt"
        $mergedFile = Join-Path $tempFolder "merged.mp4"
        Invoke-CutFFmpeg -arguments @("-i", $sourceFile, "-map", "0:$($selected.index)", "-c:s", "srt", $extractedFile) `
            -logPath $subtitleLog -description "Subtitle extraction"

        $content = [System.IO.File]::ReadAllText($extractedFile, [System.Text.Encoding]::UTF8)
        $cutContent = Convert-CutSubtitle -content $content -ranges $ranges
        if ([string]::IsNullOrWhiteSpace($cutContent))
        {
            Write-UTCLog "No subtitle cues remain in the retained video segments." "Yellow"
            return
        }
        [System.IO.File]::WriteAllText($shiftedFile, $cutContent, [System.Text.UTF8Encoding]::new($false))

        $mergeArgs = @(
            "-i", $targetFile, "-i", $shiftedFile,
            "-map", "0:v:0", "-map", "0:a:0?", "-map", "1:s:0",
            "-c:v", "copy", "-c:a", "copy", "-c:s", "mov_text",
            "-map_metadata", "0", "-map_chapters", "0", "-disposition:s:0", "default"
        )
        foreach ($tag in @("language", "title"))
        {
            if ($selected.tags.$tag) { $mergeArgs += @("-metadata:s:s:0", "$tag=$($selected.tags.$tag)") }
        }
        # MP4 exposes the track label as handler_name rather than title.
        $subtitleTitle = if ($selected.tags.title) { $selected.tags.title } else { $selected.tags.handler_name }
        if ($subtitleTitle) { $mergeArgs += @("-metadata:s:s:0", "handler_name=$subtitleTitle") }
        $mergeArgs += $mergedFile
        Invoke-CutFFmpeg -arguments $mergeArgs -logPath "$subtitleLog.merge.log" -description "Subtitle merge"
        Assert-CutVideo -path $mergedFile -logPath "$subtitleLog.merge.log"
        Move-Item -LiteralPath $mergedFile -Destination $targetFile -Force -ErrorAction Stop
    }
    finally
    {
        Remove-Item -LiteralPath $tempFolder -Recurse -Force -ErrorAction Stop
    }
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

    $audioStreams = @(Get-StreamInfo -FilePath $filename | Where-Object { $_.codec_type -eq "audio" })
    $autoSelectAudio = $PSBoundParameters.ContainsKey('AudioStreamIndex') -or
        $PSBoundParameters.ContainsKey('AudioCodec') -or $PSBoundParameters.ContainsKey('AudioChannels') -or
        $PSBoundParameters.ContainsKey('AudioLanguage')
    $selectedAudio = Select-CutAudioStream -streams $audioStreams -streamIndex $AudioStreamIndex `
        -autoSelect:$autoSelectAudio -codec $AudioCodec -channels $AudioChannels -language $AudioLanguage
    $audiobitrate = 0
    $bitrate_audio = 96
    if ($selectedAudio)
    {
        $sourceAudioBitrate = 0L
        if ([long]::TryParse([string]$selectedAudio.bit_rate, [ref]$sourceAudioBitrate) -and $sourceAudioBitrate -gt 0)
        {
            $audiobitrate = [int]($sourceAudioBitrate / 1000)
            $bitrate_audio = [math]::Min(96, [math]::Max(1, $audiobitrate))
        }
        Write-UTCLog "Selected audio stream $($selectedAudio.index): $($selectedAudio.codec_name), $($selectedAudio.channels) channels, language=$($selectedAudio.tags.language)"
    }
    else
    {
        Write-UTCLog "No audio stream found; output will contain no audio." "Yellow"
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
    $videoEncodeOptions = @("-c:v", $gpu, "-b:v", "$($bitrate)k")
    if ($PSBoundParameters.ContainsKey('crf'))
    {
        $videoEncodeOptions = @("-c:v", $gpu, "-crf", "$crf", "-preset", "slow")
    }

    $ffmpegArgs = @("-i", $filename)
    if ($revert -and ($startsecsValue -gt 0) -and ($endsecs -lt $videodurationSeconds))
    {
        if (!$selectedAudio)
        {
            $filterComplex = "[0:v]trim=start=0:end=$($startsecsValue),setpts=PTS-STARTPTS[v0];[0:v]trim=start=$($endsecs):end=$($videodurationSeconds),setpts=PTS-STARTPTS[v1];[v0][v1]concat=n=2:v=1:a=0,scale=1920:-2,format=nv12[vout]"
            $ffmpegArgs += @("-filter_complex", $filterComplex, "-map", "[vout]") + $videoEncodeOptions
        }
        else
        {
            $filterComplex = "[0:v]trim=start=0:end=$($startsecsValue),setpts=PTS-STARTPTS[v0];[0:$($selectedAudio.index)]atrim=start=0:end=$($startsecsValue),asetpts=PTS-STARTPTS[a0];[0:v]trim=start=$($endsecs):end=$($videodurationSeconds),setpts=PTS-STARTPTS[v1];[0:$($selectedAudio.index)]atrim=start=$($endsecs):end=$($videodurationSeconds),asetpts=PTS-STARTPTS[a1];[v0][a0][v1][a1]concat=n=2:v=1:a=1[vcat][acat];[vcat]scale=1920:-2,format=nv12[vout]"
            $ffmpegArgs += @("-filter_complex", $filterComplex, "-map", "[vout]", "-map", "[acat]") +
                $videoEncodeOptions + @("-c:a", "aac", "-b:a", "$($bitrate_audio)k")
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

        $ffmpegArgs += @("-ss", $startTimestamp, "-to", $endTimestamp) + $videoEncodeOptions +
            @("-pix_fmt", "nv12", "-vf", "scale=1920:-2", "-map", "0:v:0?")
        if ($selectedAudio)
        {
            $ffmpegArgs += @("-map", "0:$($selectedAudio.index)", "-c:a", "aac", "-b:a", "$($bitrate_audio)k")
        }
    }
    if ($selectedAudio)
    {
        $ffmpegArgs += @("-map_metadata:s:a:0", "0:s:$($selectedAudio.index)")
    }
    $ffmpegArgs += @("-map_chapters", "0", "-map_metadata", "0", "-f", "mp4", "-threads", "0", $outputfile)
    Write-UTCLog "Cut/Encode Start : $($filename) " "Green"
    $st=Get-date
    Invoke-CutFFmpeg -arguments $ffmpegArgs -logPath $logfile -description "Video cut/encode"
    Assert-CutVideo -path $outputfile -logPath $logfile
    if (!$SkipSubtitles)
    {
        $ranges = @(
            if ($revert)
            {
                if ($startsecsValue -gt 0) { [pscustomobject]@{ Start = 0.0; End = $startsecsValue } }
                if ($endsecs -lt $videodurationSeconds) { [pscustomobject]@{ Start = $endsecs; End = $videodurationSeconds } }
            }
            else
            {
                [pscustomobject]@{ Start = $startsecsValue; End = $endsecs }
            }
        )
        Add-CutSubtitle -sourceFile $filename -targetFile $outputfile -subtitleLog "$logfile.subtitle.log" `
            -ranges $ranges -streamIndex $SubtitleStreamIndex -preferredLanguage $SubtitleLanguage
    }
    $et=Get-date
    Write-UTCLog "Cut/Encode Complete : $($outputfile)" "Cyan"
    Write-UTCLog "Total time : $(($et-$st).TotalSeconds) (secs)" "Cyan"
}
else
{
    Write-UTCLog "File $($filename) or Folder $($outputfolder) does not exist, please recheck"  "Red"
}
