#Requires -Version 5.1

function Get-StreamInfo {
    param(
        [string]$FilePath
    )

    $tempBase = Join-Path ([System.IO.Path]::GetTempPath()) ("ffprobe_" + [guid]::NewGuid().ToString("N"))
    $tempJsonFile = "$tempBase.json"
    $tempErrFile = "$tempBase.err"
    try {
        # File redirection avoids console-codepage decoding of Chinese metadata in PowerShell 5.1.
        $process = Start-Process -FilePath "ffprobe" `
            -ArgumentList (ConvertTo-NativeArgumentString -Arguments @("-v", "error", "-print_format", "json", "-show_streams", $FilePath)) `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $tempJsonFile -RedirectStandardError $tempErrFile -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            $details = Get-Content -LiteralPath $tempErrFile -Raw -Encoding UTF8 -ErrorAction Stop
            throw "ffprobe failed with exit code $($process.ExitCode): $details"
        }
        $streamJson = Get-Content -LiteralPath $tempJsonFile -Raw -Encoding UTF8 -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
        return $streamJson.streams
    }
    finally {
        foreach ($path in @($tempJsonFile, $tempErrFile)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            }
        }
    }
}

function ConvertTo-NativeArgumentString {
    param(
        [string[]]$Arguments
    )

    return (($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join " ")
}

function Invoke-FFmpegWithLogging {
    param(
        [string[]]$Arguments,
        [string]$LogFile,
        [string]$Description = "FFmpeg"
    )

    $argumentString = ConvertTo-NativeArgumentString -Arguments $Arguments
    Write-Host "        Command: ffmpeg $argumentString" -ForegroundColor DarkGray
    Write-Host "        Log: $LogFile" -ForegroundColor DarkGray

    # Redirect stderr outside PowerShell's error pipeline (also on Windows PowerShell 5.1).
    $proc = Start-Process -FilePath "ffmpeg" `
        -ArgumentList $argumentString `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardError $LogFile `
        -ErrorAction Stop

    return $proc
}

function Find-BestAudioStream {
    param(
        [array]$Streams,
        [string]$PreferredCodec = "aac",
        [int]$PreferredChannels = 2,
        [string]$PreferredLanguage = ""
    )

    $audioStreams = @($Streams | Where-Object { $_.codec_type -eq "audio" })
    if ($audioStreams.Count -eq 0) {
        return -1
    }

    $scored = $audioStreams | ForEach-Object {
        $score = 0
        if ($_.codec_name -eq $PreferredCodec) { $score += 100 }
        if ($_.channels -eq $PreferredChannels) { $score += 50 }
        if ($PreferredLanguage -and $_.tags.language -eq $PreferredLanguage) { $score += 30 }
        if ($_.bit_rate) { $score += [math]::Min([int]$_.bit_rate / 10000, 10) }
        [PSCustomObject]@{
            Index = $_.index
            Score = $score
        }
    }

    $best = $scored | Sort-Object -Property Score -Descending | Select-Object -First 1
    return $best.Index
}

function Find-BestSubtitleStream {
    param(
        [array]$Streams,
        [string]$PreferredLanguage = "chi"
    )

    $subtitleStreams = @($Streams | Where-Object { $_.codec_type -eq "subtitle" })
    if ($subtitleStreams.Count -eq 0) {
        return -1
    }

    $scored = $subtitleStreams | ForEach-Object {
        $score = 0
        $stream = $_
        $lang = if ($stream.tags.language) { $stream.tags.language.ToLower() } else { "" }
        $title = if ($stream.tags.title) { $stream.tags.title.ToLower() } else { "" }

        if ($PreferredLanguage -eq "chi" -or $PreferredLanguage -eq "zh") {
            if ($lang -match "chi|zh|chs|zho|chinese" -or $title -match "\u7b80\u4f53|\u4e2d\u6587|chinese|simplified") {
                $score += 100
            }
        } elseif ($lang -eq $PreferredLanguage) {
            $score += 100
        }

        if ($stream.codec_name -eq "subrip" -or $stream.codec_name -eq "srt") {
            $score += 20
        }
        if ($stream.disposition.forced -eq 1) {
            $score += 10
        }
        if ($stream.disposition.default -eq 1) {
            $score += 5
        }

        [PSCustomObject]@{
            Index = $stream.index
            Score = $score
        }
    }

    $best = $scored | Sort-Object -Property Score -Descending | Select-Object -First 1
    return $best.Index
}
