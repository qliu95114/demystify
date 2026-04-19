# Universal Video Transcoding Script with Subtitle Time-Shifting
# Supports: Header/Trailer cutting, Audio/Subtitle selection, Format conversion
# Output: MP4 with HEVC video, AAC audio, and optional subtitles

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceDir,

    [Parameter(Mandatory=$true)]
    [string]$TargetDir,

    [Parameter(Mandatory=$false)]
    [int]$HeaderCutSeconds = 0,

    [Parameter(Mandatory=$false)]
    [int]$TrailCutSeconds = 0,

    # Manual stream selection (overrides auto-detection)
    [Parameter(Mandatory=$false)]
    [int]$AudioStreamIndex = -1,

    [Parameter(Mandatory=$false)]
    [int]$SubtitleStreamIndex = -1,

    # Auto-detection preferences
    [Parameter(Mandatory=$false)]
    [string]$AudioLanguage = "",

    [Parameter(Mandatory=$false)]
    [string]$AudioCodec = "aac",

    [Parameter(Mandatory=$false)]
    [int]$AudioChannels = 2,

    [Parameter(Mandatory=$false)]
    [string]$SubtitleLanguage = "chi",

    [Parameter(Mandatory=$false)]
    [int]$VideoBitrate = 2300,

    [Parameter(Mandatory=$false)]
    [int]$AudioBitrate = 128,

    [Parameter(Mandatory=$false)]
    [int]$VideoWidth = 1920,

    [Parameter(Mandatory=$false)]
    [int]$VideoHeight = 804,

    [Parameter(Mandatory=$false)]
    [string]$VideoCodec = "hevc_qsv",

    [Parameter(Mandatory=$false)]
    [string]$OutputFormat = "mp4"
)

# Validate source directory
if (!(Test-Path -Path $SourceDir)) {
    Write-Host "ERROR: Source directory does not exist: $SourceDir" -ForegroundColor Red
    exit 1
}

# Create target directory
if (!(Test-Path -Path $TargetDir)) {
    New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
    Write-Host "Created target directory: $TargetDir" -ForegroundColor Green
}

$TempDir = "$env:TEMP\transcode_temp"
if (!(Test-Path -Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}

$LogDir = "G:\DOWNLOADS\ffmpeg_log\cut"
if (!(Test-Path -Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Convert-SecondsToTimeCode {
    param([int]$Seconds)
    $hours = [math]::Floor($Seconds / 3600)
    $minutes = [math]::Floor(($Seconds % 3600) / 60)
    $secs = $Seconds % 60
    return ("{0:00}:{1:00}:{2:00}" -f $hours, $minutes, $secs)
}

function Invoke-FFmpegWithLogging {
    param(
        [string[]]$Arguments,
        [string]$LogFile,
        [string]$Description = "FFmpeg"
    )

    # Display the command
    $commandLine = "ffmpeg " + ($Arguments -join " ")
    Write-Host "        Command: $commandLine" -ForegroundColor DarkGray
    Write-Host "        Log: $LogFile" -ForegroundColor DarkGray

    # Execute with output redirection to log file
    $proc = Start-Process -FilePath "ffmpeg" `
        -ArgumentList $Arguments `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardError $LogFile

    return $proc
}

function Get-StreamInfo {
    param(
        [string]$FilePath
    )

    # Use ffprobe to get stream information in JSON format
    # Save to temp file first to avoid encoding issues with Chinese characters
    $tempJsonFile = Join-Path -Path $env:TEMP -ChildPath "ffprobe_$(Get-Random).json"

    try {
        $ffprobeArgs = @(
            "-v", "quiet",
            "-print_format", "json",
            "-show_streams",
            $FilePath
        )

        # Execute ffprobe with output redirected to file (avoids PowerShell encoding issues)
        $process = Start-Process -FilePath "ffprobe" `
            -ArgumentList $ffprobeArgs `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $tempJsonFile

        if ($process.ExitCode -ne 0) {
            throw "ffprobe failed with exit code $($process.ExitCode)"
        }

        # Read and parse JSON from file with UTF-8 encoding
        $streamJson = Get-Content -Path $tempJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json

        return $streamJson.streams
    }
    finally {
        # Clean up temp file
        if (Test-Path $tempJsonFile) {
            Remove-Item $tempJsonFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Find-BestAudioStream {
    param(
        [array]$Streams,
        [string]$PreferredCodec = "aac",
        [int]$PreferredChannels = 2,
        [string]$PreferredLanguage = ""
    )

    $audioStreams = $Streams | Where-Object { $_.codec_type -eq "audio" }

    if ($audioStreams.Count -eq 0) {
        return -1
    }

    # Score each audio stream
    $scored = $audioStreams | ForEach-Object {
        $score = 0
        $stream = $_

        # Codec match (highest priority)
        if ($stream.codec_name -eq $PreferredCodec) {
            $score += 100
        }

        # Channel count match
        if ($stream.channels -eq $PreferredChannels) {
            $score += 50
        }

        # Language match (if specified)
        if ($PreferredLanguage -and $stream.tags.language -eq $PreferredLanguage) {
            $score += 30
        }

        # Prefer higher bitrate as tiebreaker
        if ($stream.bit_rate) {
            $score += [math]::Min([int]$stream.bit_rate / 10000, 10)
        }

        [PSCustomObject]@{
            Index = $stream.index
            Score = $score
            Codec = $stream.codec_name
            Channels = $stream.channels
            Language = if ($stream.tags.language) { $stream.tags.language } else { "unknown" }
            Bitrate = if ($stream.bit_rate) { [int]$stream.bit_rate } else { 0 }
        }
    }

    # Return the stream with highest score
    $best = $scored | Sort-Object -Property Score -Descending | Select-Object -First 1
    return $best.Index
}

function Find-BestSubtitleStream {
    param(
        [array]$Streams,
        [string]$PreferredLanguage = "chi"
    )

    $subtitleStreams = $Streams | Where-Object { $_.codec_type -eq "subtitle" }

    if ($subtitleStreams.Count -eq 0) {
        return -1
    }

    # Score each subtitle stream
    $scored = $subtitleStreams | ForEach-Object {
        $score = 0
        $stream = $_

        # Language match
        $lang = if ($stream.tags.language) { $stream.tags.language.ToLower() } else { "" }
        $title = if ($stream.tags.title) { $stream.tags.title.ToLower() } else { "" }

        # Check for Chinese variants
        if ($PreferredLanguage -eq "chi" -or $PreferredLanguage -eq "zh") {
            if ($lang -match "chi|zh|chs|zho|chinese" -or $title -match "简体|中文|chinese|simplified") {
                $score += 100
            }
        } elseif ($lang -eq $PreferredLanguage) {
            $score += 100
        }

        # Prefer SRT format
        if ($stream.codec_name -eq "subrip" -or $stream.codec_name -eq "srt") {
            $score += 20
        }

        # Prefer forced/default subtitles
        if ($stream.disposition.forced -eq 1) {
            $score += 10
        }
        if ($stream.disposition.default -eq 1) {
            $score += 5
        }

        [PSCustomObject]@{
            Index = $stream.index
            Score = $score
            Codec = $stream.codec_name
            Language = $lang
            Title = $title
        }
    }

    # Return the stream with highest score
    $best = $scored | Sort-Object -Property Score -Descending | Select-Object -First 1
    return $best.Index
}

# Get all MKV and MP4 files
$Files = Get-ChildItem -Path $SourceDir -File | Where-Object { $_.Extension -in @('.mkv', '.mp4') }

if ($Files.Count -eq 0) {
    Write-Host "No video files found in $SourceDir" -ForegroundColor Red
    exit 1
}

# Display configuration
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Transcoding Configuration:" -ForegroundColor Cyan
Write-Host "  Source: $SourceDir" -ForegroundColor Gray
Write-Host "  Target: $TargetDir" -ForegroundColor Gray
Write-Host "  Files found: $($Files.Count)" -ForegroundColor Gray
Write-Host "  Output format: .$OutputFormat" -ForegroundColor Gray
Write-Host "  Video: $VideoWidth x $VideoHeight, $($VideoBitrate)k, $VideoCodec" -ForegroundColor Gray

if ($AudioStreamIndex -ge 0) {
    Write-Host "  Audio: Manual stream $AudioStreamIndex, AAC $($AudioBitrate)k stereo" -ForegroundColor Gray
} else {
    Write-Host "  Audio: Auto-detect (codec=$AudioCodec, channels=$AudioChannels)" -ForegroundColor Gray
}

if ($SubtitleStreamIndex -ge 0) {
    Write-Host "  Subtitle: Manual stream $SubtitleStreamIndex" -ForegroundColor Gray
} elseif ($SubtitleLanguage) {
    Write-Host "  Subtitle: Auto-detect (language=$SubtitleLanguage)" -ForegroundColor Gray
} else {
    Write-Host "  Subtitle: Disabled" -ForegroundColor Gray
}

if ($HeaderCutSeconds -gt 0 -or $TrailCutSeconds -gt 0) {
    Write-Host "  Cuts: Header=$HeaderCutSeconds s, Trail=$TrailCutSeconds s" -ForegroundColor Gray
}
Write-Host "================================================" -ForegroundColor Cyan

$ProcessedCount = 0
$SuccessCount = 0
$SkippedCount = 0
$FailedCount = 0
$FailedFiles = @()

foreach ($File in $Files) {
    $ProcessedCount++
    $InputFile = $File.FullName
    $OutputFile = Join-Path -Path $TargetDir -ChildPath ($File.BaseName + ".$OutputFormat")
    $TempVideoFile = Join-Path -Path $TempDir -ChildPath ($File.BaseName + "_temp.$OutputFormat")
    $TempSubtitleFile = Join-Path -Path $TempDir -ChildPath ($File.BaseName + "_temp.srt")
    $TempSubtitleShifted = Join-Path -Path $TempDir -ChildPath ($File.BaseName + "_shifted.srt")

    # Log files
    $LogExtractSub = Join-Path -Path $LogDir -ChildPath ($File.BaseName + ".extract_subtitle.log")
    $LogShiftSub = Join-Path -Path $LogDir -ChildPath ($File.BaseName + ".shift_subtitle.log")
    $LogTranscode = Join-Path -Path $LogDir -ChildPath ($File.BaseName + ".transcode.log")
    $LogMerge = Join-Path -Path $LogDir -ChildPath ($File.BaseName + ".merge.log")

    Write-Host "[$ProcessedCount/$($Files.Count)] Processing: $($File.Name)" -ForegroundColor Yellow
    Write-Host "  Input:  $InputFile"
    Write-Host "  Output: $OutputFile"

    # Check if output already exists
    if (Test-Path -Path $OutputFile) {
        Write-Host "  [SKIP] Output file already exists" -ForegroundColor Magenta
        $SkippedCount++
        Write-Host ""
        continue
    }

    try {
        # Step 1: Analyze streams and auto-detect if needed
        Write-Host "  [1/5] Analyzing streams..." -ForegroundColor Cyan

        # Get all stream information
        $AllStreams = Get-StreamInfo -FilePath $InputFile

        # Determine audio stream index
        if ($AudioStreamIndex -lt 0) {
            $DetectedAudioIndex = Find-BestAudioStream -Streams $AllStreams -PreferredCodec $AudioCodec -PreferredChannels $AudioChannels -PreferredLanguage $AudioLanguage
            if ($DetectedAudioIndex -lt 0) {
                Write-Host "  [ERROR] No suitable audio stream found" -ForegroundColor Red
                $FailedCount++
                $FailedFiles += $File.Name
                continue
            }
            $CurrentAudioIndex = $DetectedAudioIndex
            Write-Host "        Auto-detected audio stream: $CurrentAudioIndex" -ForegroundColor Gray
        } else {
            $CurrentAudioIndex = $AudioStreamIndex
            Write-Host "        Using manual audio stream: $CurrentAudioIndex" -ForegroundColor Gray
        }

        # Display audio stream details
        $audioStream = $AllStreams | Where-Object { $_.index -eq $CurrentAudioIndex }
        if ($audioStream) {
            $audioInfo = "$($audioStream.codec_name), $($audioStream.channels)ch"
            if ($audioStream.tags.language) { $audioInfo += ", lang=$($audioStream.tags.language)" }
            if ($audioStream.bit_rate) { $audioInfo += ", $([math]::Round([int]$audioStream.bit_rate / 1000))kbps" }
            Write-Host "        Audio: $audioInfo" -ForegroundColor DarkGray
        }

        # Determine subtitle stream index
        if ($SubtitleStreamIndex -lt 0) {
            $DetectedSubtitleIndex = Find-BestSubtitleStream -Streams $AllStreams -PreferredLanguage $SubtitleLanguage
            if ($DetectedSubtitleIndex -lt 0) {
                Write-Host "        No suitable subtitle stream found (will skip subtitles)" -ForegroundColor Yellow
                $CurrentSubtitleIndex = -1
            } else {
                $CurrentSubtitleIndex = $DetectedSubtitleIndex
                Write-Host "        Auto-detected subtitle stream: $CurrentSubtitleIndex" -ForegroundColor Gray
            }
        } else {
            $CurrentSubtitleIndex = $SubtitleStreamIndex
            if ($CurrentSubtitleIndex -ge 0) {
                Write-Host "        Using manual subtitle stream: $CurrentSubtitleIndex" -ForegroundColor Gray
            } else {
                Write-Host "        Subtitle disabled (index = -1)" -ForegroundColor Gray
            }
        }

        # Display subtitle stream details
        if ($CurrentSubtitleIndex -ge 0) {
            $subtitleStream = $AllStreams | Where-Object { $_.index -eq $CurrentSubtitleIndex }
            if ($subtitleStream) {
                $subInfo = "$($subtitleStream.codec_name)"
                if ($subtitleStream.tags.language) { $subInfo += ", lang=$($subtitleStream.tags.language)" }
                if ($subtitleStream.tags.title) { $subInfo += ", title=$($subtitleStream.tags.title)" }
                Write-Host "        Subtitle: $subInfo" -ForegroundColor DarkGray
            }
        }

        # Get duration
        $DurationOutput = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $InputFile
        $OriginalDuration = [double]$DurationOutput
        $OutputDuration = $OriginalDuration - $HeaderCutSeconds - $TrailCutSeconds

        if ($OutputDuration -le 0) {
            Write-Host "  [ERROR] Video is too short after cutting" -ForegroundColor Red
            $FailedCount++
            $FailedFiles += $File.Name
            continue
        }

        Write-Host "        Original: $([TimeSpan]::FromSeconds($OriginalDuration).ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        if ($HeaderCutSeconds -gt 0 -or $TrailCutSeconds -gt 0) {
            Write-Host "        Output: $([TimeSpan]::FromSeconds($OutputDuration).ToString('hh\:mm\:ss')) (cut header ${HeaderCutSeconds}s, trail ${TrailCutSeconds}s)" -ForegroundColor Gray
        }

        # Step 2: Extract subtitle (if specified)
        $HasSubtitle = $false
        if ($CurrentSubtitleIndex -ge 0) {
            Write-Host "  [2/5] Extracting subtitle from stream $CurrentSubtitleIndex..." -ForegroundColor Cyan

            $extractProc = Invoke-FFmpegWithLogging -Arguments @(
                "-i", $InputFile,
                "-map", "0:$CurrentSubtitleIndex",
                "-c", "copy",
                "-y",
                $TempSubtitleFile
            ) -LogFile $LogExtractSub -Description "Extract Subtitle"

            if ($extractProc.ExitCode -eq 0 -and (Test-Path $TempSubtitleFile)) {
                $SubSize = (Get-Item $TempSubtitleFile).Length
                if ($SubSize -gt 0) {
                    Write-Host "        Subtitle extracted successfully ($SubSize bytes)" -ForegroundColor Gray
                    $HasSubtitle = $true
                } else {
                    Write-Host "        [WARNING] Subtitle file is empty" -ForegroundColor Yellow
                }
            } else {
                Write-Host "        [WARNING] Failed to extract subtitle (exit code: $($extractProc.ExitCode))" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [2/5] Skipping subtitle extraction" -ForegroundColor Cyan
        }

        # Step 3: Timeshift subtitle (if needed)
        if ($HasSubtitle -and $HeaderCutSeconds -gt 0) {
            Write-Host "  [3/5] Time-shifting subtitle..." -ForegroundColor Cyan
            $TimeOffset = "-" + (Convert-SecondsToTimeCode -Seconds $HeaderCutSeconds)
            Write-Host "        Applying offset: $TimeOffset" -ForegroundColor Gray

            $shiftProc = Invoke-FFmpegWithLogging -Arguments @(
                "-itsoffset", $TimeOffset,
                "-i", $TempSubtitleFile,
                "-c", "copy",
                "-y",
                $TempSubtitleShifted
            ) -LogFile $LogShiftSub -Description "Timeshift Subtitle"

            if ($shiftProc.ExitCode -eq 0 -and (Test-Path $TempSubtitleShifted)) {
                Write-Host "        Subtitle time-shifted successfully" -ForegroundColor Gray
            } else {
                Write-Host "        [WARNING] Failed to timeshift (exit code: $($shiftProc.ExitCode)), using original" -ForegroundColor Yellow
                $TempSubtitleShifted = $TempSubtitleFile
            }
        } elseif ($HasSubtitle) {
            Write-Host "  [3/5] No header cut, skipping timeshift" -ForegroundColor Cyan
            $TempSubtitleShifted = $TempSubtitleFile
        } else {
            Write-Host "  [3/5] Skipping timeshift (no subtitle)" -ForegroundColor Cyan
        }

        # Step 4: Transcode video and audio
        Write-Host "  [4/5] Transcoding video and audio..." -ForegroundColor Cyan

        $ffmpegArgs = @()

        if ($HeaderCutSeconds -gt 0) {
            $ffmpegArgs += @("-ss", $HeaderCutSeconds.ToString("0.00"))
        }

        $ffmpegArgs += @(
            "-i", $InputFile,
            "-t", $OutputDuration.ToString("0.00"),
            "-map", "0:v:0",
            "-c:v", $VideoCodec,
            "-b:v", "$($VideoBitrate)k",
            "-vf", "scale=$($VideoWidth):$($VideoHeight)",
            "-map", "0:$CurrentAudioIndex",
            "-c:a", "aac",
            "-b:a", "$($AudioBitrate)k",
            "-ac", "2",
            "-y",
            $TempVideoFile
        )

        Write-Host "        Starting transcode (this may take several minutes)..." -ForegroundColor Gray
        $StartTime = Get-Date
        $transcodeProc = Invoke-FFmpegWithLogging -Arguments $ffmpegArgs -LogFile $LogTranscode -Description "Transcode Video"
        $EndTime = Get-Date

        if ($transcodeProc.ExitCode -ne 0) {
            Write-Host "  [FAILED] Video transcoding failed (exit code: $($transcodeProc.ExitCode))" -ForegroundColor Red
            $FailedCount++
            $FailedFiles += $File.Name
            continue
        }

        $Duration = $EndTime - $StartTime
        $TempSize = (Get-Item $TempVideoFile).Length / 1GB
        Write-Host "        Transcoded in $($Duration.ToString('hh\:mm\:ss')) - Size: $($TempSize.ToString('0.00')) GB" -ForegroundColor Gray

        # Step 5: Merge subtitle
        if ($HasSubtitle) {
            Write-Host "  [5/5] Merging subtitle..." -ForegroundColor Cyan

            # Determine subtitle codec based on output format
            $SubtitleCodec = if ($OutputFormat -eq "mp4") { "mov_text" } else { "srt" }

            $mergeProc = Invoke-FFmpegWithLogging -Arguments @(
                "-i", $TempVideoFile,
                "-i", $TempSubtitleShifted,
                "-map", "0:v",
                "-map", "0:a",
                "-map", "1:s",
                "-c:v", "copy",
                "-c:a", "copy",
                "-c:s", $SubtitleCodec,
                "-metadata:s:s:0", "language=chi",
                "-metadata:s:s:0", "title=简体中文",
                "-y",
                $OutputFile
            ) -LogFile $LogMerge -Description "Merge Subtitle"

            if ($mergeProc.ExitCode -eq 0) {
                Write-Host "        Subtitle merged successfully" -ForegroundColor Gray
            } else {
                Write-Host "        [WARNING] Failed to merge subtitle (exit code: $($mergeProc.ExitCode))" -ForegroundColor Yellow
                Copy-Item -Path $TempVideoFile -Destination $OutputFile -Force
            }
        } else {
            Write-Host "  [5/5] No subtitle to merge" -ForegroundColor Cyan
            Copy-Item -Path $TempVideoFile -Destination $OutputFile -Force
        }

        # Cleanup temp files
        if (Test-Path $TempVideoFile) { Remove-Item $TempVideoFile -Force }
        if (Test-Path $TempSubtitleFile) { Remove-Item $TempSubtitleFile -Force }
        if (Test-Path $TempSubtitleShifted) { Remove-Item $TempSubtitleShifted -Force }

        $OutputSize = (Get-Item $OutputFile).Length / 1GB
        Write-Host "  [SUCCESS] Completed - Output size: $($OutputSize.ToString('0.00')) GB" -ForegroundColor Green
        $SuccessCount++
        Write-Host ""

    } catch {
        Write-Host "  [ERROR] $_" -ForegroundColor Red
        Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor Red
        $FailedCount++
        $FailedFiles += $File.Name
        Write-Host ""
    }
}

# Clean up temp directory
if (Test-Path $TempDir) {
    Remove-Item -Path $TempDir -Recurse -Force
}

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Transcoding Summary:" -ForegroundColor Cyan
Write-Host "  Total files: $($Files.Count)"
Write-Host "  Successful: $SuccessCount" -ForegroundColor Green
Write-Host "  Skipped: $SkippedCount" -ForegroundColor Magenta
Write-Host "  Failed: $FailedCount" -ForegroundColor $(if ($FailedCount -gt 0) { "Red" } else { "Green" })

if ($FailedCount -gt 0) {
    Write-Host "`nFailed files:" -ForegroundColor Red
    foreach ($FailedFile in $FailedFiles) {
        Write-Host "  - $FailedFile" -ForegroundColor Red
    }
}

Write-Host "`nTranscoding complete!" -ForegroundColor Cyan
