#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$OutputDirectory,
    [ValidateSet('auto', 'zh', 'en', 'ja', 'ko', 'yue', 'fr', 'de', 'es', 'pt', 'it')]
    [string]$Language = 'auto',
    [ValidateSet('auto', 'sensevoice', 'whisper')]
    [string]$Backend = 'auto',
    [ValidateSet('cpu', 'npu', 'intel-gpu', 'amd-gpu')]
    [string]$Device = 'cpu',
    [ValidateRange(-1, 16)]
    [int]$GpuDeviceId = -1,
    [ValidateRange(1, 32)]
    [int]$Threads = 4,
    [ValidateRange(0, 100)]
    [int]$AudioStream = 0,
    [ValidateRange(30, 1800)]
    [int]$ChunkSeconds = 300,
    [switch]$Recurse,
    [switch]$InstallMissing,
    [switch]$AllowAacEncode,
    [switch]$SkipMusic,
    [switch]$Force,
    [string]$PythonPath,
    [string]$ModelSourceDir,
    [string]$RuntimeDir
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [Console]::OutputEncoding
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Language = $Language.ToLowerInvariant()
$Backend = $Backend.ToLowerInvariant()
$Device = $Device.ToLowerInvariant()
if (-not $RuntimeDir) {
    $RuntimeDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.runtime'
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $RuntimeDir 'output'
}

if (-not (Test-Path -LiteralPath $InputPath)) { throw "Input not found: $InputPath" }
$setupArguments = @{
    InstallMissing = $InstallMissing
    RuntimeDir = $RuntimeDir
    SkipMusic = $SkipMusic
    Backend = $Backend
    Language = $Language
    Device = $Device
    GpuDeviceId = $GpuDeviceId
}
if ($PythonPath) { $setupArguments.PythonPath = $PythonPath }
if ($ModelSourceDir) { $setupArguments.ModelSourceDir = $ModelSourceDir }
$tools = & (Join-Path $PSScriptRoot 'Setup-VideoSrt.ps1') @setupArguments
$workerArguments = @(
    (Join-Path $PSScriptRoot 'transcribe.py'),
    '--input', [IO.Path]::GetFullPath($InputPath),
    '--output-dir', [IO.Path]::GetFullPath($OutputDirectory),
    '--model-dir', $tools.Models,
    '--ffmpeg', $tools.FFmpeg,
    '--ffprobe', $tools.FFprobe,
    '--language', $Language,
    '--backend', $tools.Backend,
    '--device', $Device,
    '--gpu-device-id', "$($tools.AcceleratorId)",
    '--accelerator-name', "$($tools.AcceleratorName)",
    '--threads', "$Threads",
    '--audio-stream', "$AudioStream",
    '--chunk-seconds', "$ChunkSeconds"
)
if ($Recurse) { $workerArguments += '--recurse' }
if ($AllowAacEncode) { $workerArguments += '--allow-aac-encode' }
if ($SkipMusic) { $workerArguments += '--skip-music' }
if ($Force) { $workerArguments += '--force' }
& $tools.Python @workerArguments
if ($LASTEXITCODE -ne 0) { throw "video-srt failed (exit $LASTEXITCODE). Fix the reported input/environment issue and rerun the same command to resume." }
