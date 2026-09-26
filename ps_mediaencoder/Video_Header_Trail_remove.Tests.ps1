. (Join-Path $PSScriptRoot "help_class.ps1")

# Load pure helpers without executing the script's encoding entry point.
$tokens = $null
$parseErrors = $null
$scriptPath = Join-Path $PSScriptRoot "Video_Header_Trail_remove.ps1"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($name in @("Convert-CutSubtitle", "Format-CutTime", "Invoke-CutFFmpeg", "Assert-CutVideo", "Select-CutAudioStream"))
{
    $function = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $false)
    Invoke-Expression $function.Extent.Text
}

Describe "Subtitle cutting" {
    $content = @"
1
00:00:00,000 --> 00:00:01,000
Header

2
00:00:01,500 --> 00:00:03,000
Cross start
Second line

3
00:00:04,000 --> 00:00:05,000
Middle

4
00:00:07,000 --> 00:00:09,000
Cross end

5
00:00:09,000 --> 00:00:10,000
Tail
"@

    It "clips boundary cues, shifts timestamps and renumbers retained cues" {
        $result = Convert-CutSubtitle $content @(@{ Start = 2.0; End = 8.0 })
        $result | Should Match "1\r?\n00:00:00,000 --> 00:00:01,000\r?\nCross start\r?\nSecond line"
        $result | Should Match "2\r?\n00:00:02,000 --> 00:00:03,000"
        $result | Should Match "3\r?\n00:00:05,000 --> 00:00:06,000"
        $result | Should Not Match "Header|Tail"
    }

    It "joins header and tail cues for revert cuts" {
        $result = Convert-CutSubtitle $content @(@{ Start = 0.0; End = 2.0 }, @{ Start = 8.0; End = 10.0 })
        $result | Should Match "00:00:01,500 --> 00:00:02,000"
        $result | Should Match "00:00:02,000 --> 00:00:03,000\r?\nCross end"
        $result | Should Match "4\r?\n00:00:03,000 --> 00:00:04,000\r?\nTail"
        $result | Should Not Match "Middle"
    }

    It "splits a cue spanning the entire removed middle" {
        $cue = "1`n00:00:01,000 --> 00:00:09,000`nSpanning"
        $result = Convert-CutSubtitle $cue @(@{ Start = 0.0; End = 2.0 }, @{ Start = 8.0; End = 10.0 })
        $result | Should Match "00:00:01,000 --> 00:00:02,000"
        $result | Should Match "2\r?\n00:00:02,000 --> 00:00:03,000"
    }

    It "supports fractional cut boundaries and a tail-only revert" {
        $result = Convert-CutSubtitle $content @(@{ Start = 8.25; End = 9.75 })
        $result | Should Match "00:00:00,000 --> 00:00:00,750"
        $result | Should Match "00:00:00,750 --> 00:00:01,500"
        Format-CutTime 8.25 | Should Be "00:00:08.250"
    }

    It "discards cues that only touch the retained interval" {
        Convert-CutSubtitle $content @(@{ Start = 3.0; End = 4.0 }) | Should Be ""
    }

    It "handles empty extracted subtitles" {
        Convert-CutSubtitle "" @(@{ Start = 0.0; End = 10.0 }) | Should Be ""
    }

    It "rejects malformed subtitle cues" {
        { Convert-CutSubtitle "invalid cue" @(@{ Start = 0.0; End = 10.0 }) } | Should Throw "Invalid SRT cue"
    }
}

Describe "Shared subtitle stream selection" {
    $streams = @(
        [pscustomobject]@{ index = 2; codec_type = "subtitle"; codec_name = "subrip"; tags = @{ language = "eng" }; disposition = @{ default = 1 } }
        [pscustomobject]@{ index = 3; codec_type = "subtitle"; codec_name = "ass"; tags = @{ language = "chi" }; disposition = @{} }
        [pscustomobject]@{ index = 4; codec_type = "subtitle"; codec_name = "subrip"; tags = @{ language = "chi" }; disposition = @{} }
    )

    It "prefers Chinese and then SRT by default" {
        Find-BestSubtitleStream $streams | Should Be 4
    }

    It "honors the preferred language" {
        Find-BestSubtitleStream $streams "eng" | Should Be 2
    }

    It "recognizes a Chinese title without a language tag" {
        $stream = [pscustomobject]@{
            index = 5; codec_type = "subtitle"; codec_name = "ass"
            tags = @{ title = ([string][char]0x7b80 + [char]0x4f53) }; disposition = @{}
        }
        Find-BestSubtitleStream @($streams[0], $stream) | Should Be 5
    }

    It "returns no stream for an empty input" {
        Find-BestSubtitleStream @() | Should Be -1
    }
}

Describe "Audio track selection" {
    $streams = @(
        [pscustomobject]@{ index = 0; codec_type = "video" }
        [pscustomobject]@{ index = 1; codec_type = "audio"; codec_name = "eac3"; channels = 6; tags = @{ language = "chi" }; bit_rate = "256000" }
        [pscustomobject]@{ index = 3; codec_type = "audio"; codec_name = "aac"; channels = 2; tags = @{ language = "eng" }; bit_rate = "128000" }
        [pscustomobject]@{ index = 4; codec_type = "audio"; codec_name = "aac"; channels = 2; tags = @{ language = "chi" }; bit_rate = "96000" }
        [pscustomobject]@{ index = 5; codec_type = "subtitle" }
    )

    It "preserves first-track selection without automatic selection" {
        (Select-CutAudioStream -streams $streams).index | Should Be 1
    }

    It "selects AAC stereo by default when automatic selection is enabled" {
        (Select-CutAudioStream -streams $streams -autoSelect).index | Should Be 3
    }

    It "uses language to rank otherwise matching tracks" {
        (Select-CutAudioStream -streams $streams -autoSelect -language chi).index | Should Be 4
    }

    It "honors codec and channel preferences" {
        (Select-CutAudioStream -streams $streams -autoSelect -codec eac3 -channels 6).index | Should Be 1
    }

    It "lets a manual absolute index override all preferences" {
        (Select-CutAudioStream -streams $streams -streamIndex 1 -autoSelect -codec aac -channels 2 -language eng).index | Should Be 1
    }

    It "rejects missing, video and subtitle indexes" {
        foreach ($index in @(0, 2, 5)) {
            { Select-CutAudioStream -streams $streams -streamIndex $index } | Should Throw "not an audio stream"
        }
    }

    It "supports files without audio unless an explicit track was requested" {
        @(Select-CutAudioStream -streams @() -autoSelect).Count | Should Be 0
        { Select-CutAudioStream -streams @() -streamIndex 1 } | Should Throw "not an audio stream"
    }

    It "falls back to available audio when no preference matches" {
        (Select-CutAudioStream -streams @($streams[1]) -autoSelect -language jpn).index | Should Be 1
    }
}

Describe "FFmpeg process handling" {
    function ffprobe { throw "ffprobe must be mocked in process-handling tests." }

    It "waits for FFmpeg with native log redirection and keyboard input disabled" {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        Invoke-CutFFmpeg -arguments @("-i", 'D:\input folder\video.mkv', 'D:\output folder\video.mp4') `
            -logPath "TestDrive:\encode.log" -description "Video cut/encode"
        Assert-MockCalled Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "ffmpeg" -and $Wait -and $PassThru -and
            $RedirectStandardError -eq "TestDrive:\encode.log" -and
            $ArgumentList -eq '-nostdin -y -i "D:\input folder\video.mkv" "D:\output folder\video.mp4"'
        }
    }

    It "reports native exit codes and the error log" {
        Mock Invoke-FFmpegWithLogging { [pscustomobject]@{ ExitCode = 42 } }
        Mock Get-Content { "Encoder initialization failed" }
        { Invoke-CutFFmpeg -arguments @("-version") -logPath "TestDrive:\encode.log" -description "Video cut/encode" } |
            Should Throw "FFmpeg exit code 42"
    }

    It "rejects an empty MP4 even when ffprobe reports success" {
        Mock ffprobe { $global:LASTEXITCODE = 0; '{"streams":[]}' }
        { Assert-CutVideo -path "TestDrive:\empty.mp4" -logPath "TestDrive:\encode.log" } |
            Should Throw "no video frames"
    }

    It "accepts an encoded video stream with a positive duration" {
        Mock ffprobe { $global:LASTEXITCODE = 0; '{"streams":[{"codec_type":"video","duration":"30.000000"}]}' }
        { Assert-CutVideo -path "TestDrive:\video.mp4" -logPath "TestDrive:\encode.log" } |
            Should Not Throw
    }
}
