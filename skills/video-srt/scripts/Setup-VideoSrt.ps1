#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$InstallMissing,
    [string]$PythonPath,
    [string]$ModelSourceDir,
    [string]$RuntimeDir,
    [switch]$SkipMusic,
    [ValidateSet('auto', 'sensevoice', 'whisper')]
    [string]$Backend = 'auto',
    [ValidateSet('auto', 'zh', 'en', 'ja', 'ko', 'yue', 'fr', 'de', 'es', 'pt', 'it')]
    [string]$Language = 'auto'
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [Console]::OutputEncoding
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$Language = $Language.ToLowerInvariant()
$Backend = $Backend.ToLowerInvariant()
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUTF8 = '1'
if (-not $RuntimeDir) {
    $RuntimeDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.runtime'
}

if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
    throw 'This bootstrap supports 64-bit Windows. Run it from PowerShell 7 or Windows PowerShell 5.1.'
}

function Refresh-ToolPath {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$env:Path;$machine;$user"
}

function Install-WingetTool {
    param([string]$Id)
    if (-not $InstallMissing) {
        throw "Missing prerequisite $Id. Rerun with -InstallMissing, or install it manually."
    }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget is unavailable. Install Microsoft App Installer, or install $Id manually and rerun."
    }
    Write-Host "Installing missing software: $Id"
    & $winget.Source install --id $Id --exact --source winget --scope user --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "winget could not install $Id (exit $LASTEXITCODE). Install it manually, then rerun."
    }
    Refresh-ToolPath
}

function Find-Python {
    param([string]$ExplicitPath)
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($ExplicitPath) {
        $resolved = Get-Command $ExplicitPath -ErrorAction Stop
        $candidates.Add($resolved.Source)
    } else {
        foreach ($name in @('python.exe', 'python3.exe')) {
            $command = Get-Command $name -ErrorAction SilentlyContinue
            if ($command -and $command.Source -notlike '*\WindowsApps\*') {
                $candidates.Add($command.Source)
            }
        }
        foreach ($version in @('314', '313', '312', '311')) {
            $known = Join-Path $env:LOCALAPPDATA "Programs\Python\Python$version\python.exe"
            if (Test-Path -LiteralPath $known) { $candidates.Add($known) }
        }
        $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
        if ($launcher) {
            # Enumerate interpreters instead of launching a Windows Store alias.
            $listed = @(& $launcher.Source --list-paths)
            if ($LASTEXITCODE -eq 0) {
                foreach ($line in $listed) {
                    if ($line -match '([A-Za-z]:\\.*python\.exe)\s*$') {
                        $candidates.Add($Matches[1])
                    }
                }
            }
        }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $details = @(& $candidate -c "import sys,struct,platform; print(sys.executable); sys.exit(0 if (3,11)<=sys.version_info[:2]<(3,15) and struct.calcsize('P')==8 and platform.machine().lower() in ('amd64','x86_64') else 1)")
        if ($LASTEXITCODE -eq 0) { return [string]$details[-1] }
        Write-Host "Ignoring incompatible Python: $candidate (requires CPython 3.11-3.14, Windows x64)."
    }
    if ($ExplicitPath) { throw "The requested Python is incompatible: $ExplicitPath" }
    return $null
}

$python = Find-Python $PythonPath
if (-not $python) {
    Install-WingetTool 'Python.Python.3.12'
    $python = Find-Python
    if (-not $python) { throw 'Python installation finished but no compatible interpreter was found. Reopen PowerShell and retry.' }
}

$helper = Join-Path $PSScriptRoot 'setup_models.py'
$backendResult = & $python $helper --resolve-backend --backend $Backend --language $Language
if ($LASTEXITCODE -ne 0) { throw 'Unsupported backend/language combination; see the error above.' }
$resolvedBackend = ([string]$backendResult).Trim()

$ffmpeg = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
$ffprobe = Get-Command ffprobe.exe -ErrorAction SilentlyContinue
if (-not $ffmpeg -or -not $ffprobe) {
    Install-WingetTool 'Gyan.FFmpeg'
    $ffmpeg = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    $ffprobe = Get-Command ffprobe.exe -ErrorAction SilentlyContinue
    if (-not $ffmpeg -or -not $ffprobe) { throw 'FFmpeg/FFprobe not found after installation. Reopen PowerShell and retry.' }
}
foreach ($tool in @($ffmpeg, $ffprobe)) {
    & $tool.Source -version | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "$($tool.Name) failed its executable check." }
}
Write-Host "Python: $python"
Write-Host "FFmpeg: $($ffmpeg.Source)"
Write-Host "FFprobe: $($ffprobe.Source)"
Write-Host "CPU inference; no CUDA, GPU or cloud credentials required."
Write-Host "ASR backend: $resolvedBackend; language: $Language"
if ($resolvedBackend -eq 'sensevoice' -and $Language -eq 'auto') {
    Write-Host 'SenseVoice auto-detects only its five supported languages. Use -Backend whisper -Language auto for broader detection.'
}

$RuntimeDir = [IO.Path]::GetFullPath($RuntimeDir)
$venv = Join-Path $RuntimeDir 'venv'
$venvPython = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) {
    if (-not $InstallMissing) { throw 'Skill environment is missing. Rerun with -InstallMissing to create it.' }
    New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null
    & $python -m venv $venv | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the isolated Python environment.' }
}

& $venvPython $helper --check-runtime | Out-Host
if ($LASTEXITCODE -ne 0) {
    if (-not $InstallMissing) { throw 'Python dependencies are missing or incompatible. Rerun with -InstallMissing.' }
    & $venvPython -m pip --version | Out-Host
    if ($LASTEXITCODE -ne 0) {
        & $venvPython -m ensurepip | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'pip is unavailable; repair this Python installation.' }
    }
    & $venvPython -m pip install --only-binary=:all: --requirement (Join-Path $PSScriptRoot 'requirements.txt') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed. Use compatible Windows x64 Python and check network access.' }
    & $venvPython $helper --check-runtime | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Installed runtime could not load. Check the Python architecture and native runtime error above.' }
}

$models = Join-Path $RuntimeDir 'models'
$modelArguments = @($helper, '--model-dir', $models, '--backend', $resolvedBackend, '--language', $Language)
if ($InstallMissing) { $modelArguments += '--download' }
if ($SkipMusic) { $modelArguments += '--skip-music' }
if ($ModelSourceDir) {
    if (-not (Test-Path -LiteralPath $ModelSourceDir -PathType Container)) {
        throw "Model source directory not found: $ModelSourceDir"
    }
    $modelArguments += @('--import-from', [IO.Path]::GetFullPath($ModelSourceDir))
}
& $venvPython @modelArguments | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Model preparation failed; see the explicit error above. No media was uploaded.' }

[pscustomobject]@{
    Python = $venvPython
    FFmpeg = $ffmpeg.Source
    FFprobe = $ffprobe.Source
    Models = $models
    Runtime = $RuntimeDir
    Backend = $resolvedBackend
}
