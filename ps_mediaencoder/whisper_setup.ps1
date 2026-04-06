#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup script for Whisper Subtitle Generator

.DESCRIPTION
    Prepares a machine for running the Whisper subtitle generator by:
    - Checking Python installation (3.8+)
    - Checking ffmpeg installation
    - Installing faster-whisper and dependencies
    - Optionally pre-downloading models
    - Verifying the installation

.PARAMETER SkipChecks
    Skip prerequisite checks and force installation

.PARAMETER DownloadModels
    Comma-separated list of models to pre-download (e.g., "medium,large-v3")
    Available: tiny, base, small, medium, large-v2, large-v3
    If not specified, models will be downloaded on first use

.EXAMPLE
    .\whisper_setup.ps1
    Run the setup with default settings (no model pre-download)

.EXAMPLE
    .\whisper_setup.ps1 -DownloadModels "medium"
    Setup and pre-download medium model (~1.5GB)

.EXAMPLE
    .\whisper_setup.ps1 -DownloadModels "medium,large-v3"
    Setup and pre-download medium and large-v3 models (~4.5GB total)

.EXAMPLE
    .\whisper_setup.ps1 -SkipChecks -DownloadModels "tiny,base,small,medium,large-v3"
    Skip checks and download all models

.NOTES
    Author: Created for faster-whisper subtitle generation
    Requirements: Python 3.8+, ffmpeg
#>

[CmdletBinding()]
param(
    [switch]$SkipChecks,

    [Parameter(Mandatory=$false)]
    [string]$DownloadModels = ""
)

$ErrorActionPreference = "Continue"

Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "Whisper Subtitle Generator - Setup Script" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""

# Function to check if command exists
function Test-CommandExists {
    param($Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Step 1: Check Python
Write-Host "[1/5] Checking Python installation..." -ForegroundColor Yellow
if (-not (Test-CommandExists "python")) {
    Write-Host "  [ERROR] Python not found!" -ForegroundColor Red
    Write-Host "  Please install Python 3.8+ from: https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "  Or use: winget install Python.Python.3.12" -ForegroundColor Yellow
    exit 1
}

$pythonVersion = python --version 2>&1 | Out-String
Write-Host "  [OK] Found: $($pythonVersion.Trim())" -ForegroundColor Green

# Check Python version
$versionMatch = $pythonVersion -match "Python (\d+)\.(\d+)"
if ($versionMatch) {
    $majorVersion = [int]$Matches[1]
    $minorVersion = [int]$Matches[2]
    if ($majorVersion -lt 3 -or ($majorVersion -eq 3 -and $minorVersion -lt 8)) {
        Write-Host "  [ERROR] Python 3.8+ required (found $majorVersion.$minorVersion)" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Check pip
Write-Host "`n[2/5] Checking pip..." -ForegroundColor Yellow
if (-not (Test-CommandExists "pip")) {
    Write-Host "  [ERROR] pip not found!" -ForegroundColor Red
    Write-Host "  Install with: python -m ensurepip --upgrade" -ForegroundColor Yellow
    exit 1
}
$pipVersion = pip --version 2>&1 | Out-String
Write-Host "  [OK] Found: $($pipVersion.Trim())" -ForegroundColor Green

# Step 3: Check ffmpeg
Write-Host "`n[3/5] Checking ffmpeg installation..." -ForegroundColor Yellow
if (-not (Test-CommandExists "ffmpeg")) {
    Write-Host "  [WARNING] ffmpeg not found!" -ForegroundColor Yellow
    Write-Host "  ffmpeg is required for processing video files" -ForegroundColor Yellow
    Write-Host "  Install with: winget install Gyan.FFmpeg" -ForegroundColor Cyan
    Write-Host "  Or download from: https://ffmpeg.org/download.html" -ForegroundColor Cyan
    Write-Host ""
    if (-not $SkipChecks) {
        $continue = Read-Host "Continue without ffmpeg? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            exit 1
        }
    }
} else {
    $ffmpegVersion = ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] Found: $ffmpegVersion" -ForegroundColor Green
}

# Step 4: Install faster-whisper
Write-Host "`n[4/5] Installing faster-whisper..." -ForegroundColor Yellow
Write-Host "  This may take several minutes..." -ForegroundColor Gray

pip install faster-whisper --upgrade
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] faster-whisper installed successfully" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Installation failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

# Step 5: Verify installation
Write-Host "`n[5/5] Verifying installation..." -ForegroundColor Yellow

$verifyScript = @"
from faster_whisper import WhisperModel
import sys
print(f'faster-whisper: OK')
print(f'Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')
"@

$verifyOutput = python -c $verifyScript 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Verification successful" -ForegroundColor Green
    Write-Host "  $($verifyOutput.Trim())" -ForegroundColor Gray
} else {
    Write-Host "  [WARNING] Verification failed" -ForegroundColor Yellow
    Write-Host $verifyOutput
}

# Step 6: Download models (optional)
if ($DownloadModels -ne "") {
    Write-Host "`n[6/6] Pre-downloading models..." -ForegroundColor Yellow
    Write-Host "  This will download models for offline use" -ForegroundColor Gray
    Write-Host ""

    $modelList = $DownloadModels -split ',' | ForEach-Object { $_.Trim() }
    $totalModels = $modelList.Count
    $currentModel = 0

    foreach ($model in $modelList) {
        $currentModel++
        Write-Host "  [$currentModel/$totalModels] Downloading model: $model" -ForegroundColor Cyan

        # Get model size info
        $modelSize = switch ($model) {
            "tiny" { "~75MB" }
            "base" { "~145MB" }
            "small" { "~480MB" }
            "medium" { "~1.5GB" }
            "large-v2" { "~3GB" }
            "large-v3" { "~3GB" }
            default { "unknown size" }
        }

        Write-Host "       Size: $modelSize (one-time download)" -ForegroundColor Gray

        $downloadScript = @"
from faster_whisper import WhisperModel
import sys

try:
    print('Loading model: $model')
    model = WhisperModel('$model', device='cpu', compute_type='int8')
    print('Model downloaded and cached successfully')
    sys.exit(0)
except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
"@

        $downloadOutput = python -c $downloadScript 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Host "       [OK] Model cached successfully" -ForegroundColor Green
        } else {
            Write-Host "       [ERROR] Download failed for $model" -ForegroundColor Red
            Write-Host $downloadOutput
        }
        Write-Host ""
    }

    Write-Host "  [OK] Model pre-download complete" -ForegroundColor Green
}

# Success message
Write-Host "`n" + "=" * 70 -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Green
Write-Host ""
Write-Host "Available models (speed vs accuracy):" -ForegroundColor Cyan
Write-Host "  tiny     - Fastest, lowest accuracy (~75MB)" -ForegroundColor Gray
Write-Host "  base     - Fast, decent accuracy (~145MB)" -ForegroundColor Gray
Write-Host "  small    - Balanced (~480MB)" -ForegroundColor Gray
Write-Host "  medium   - Good accuracy (~1.5GB) [Recommended]" -ForegroundColor Yellow
Write-Host "  large-v3 - Best accuracy (~3GB)" -ForegroundColor Gray
Write-Host ""

if ($DownloadModels -ne "") {
    Write-Host "Models downloaded and cached for offline use:" -ForegroundColor Green
    foreach ($model in ($DownloadModels -split ',' | ForEach-Object { $_.Trim() })) {
        Write-Host "  - $model" -ForegroundColor White
    }
    Write-Host ""
}

Write-Host "Quick Start:" -ForegroundColor Cyan
Write-Host "  python whisper_subtitle_generator.py video.mp4" -ForegroundColor White
Write-Host "  python whisper_subtitle_generator.py video.mp4 medium" -ForegroundColor White
Write-Host "  python whisper_subtitle_generator.py video.mp4 large-v3 en" -ForegroundColor White
Write-Host ""

if ($DownloadModels -eq "") {
    Write-Host "First run will download the model (one-time, internet required)" -ForegroundColor Gray
} else {
    Write-Host "Selected models are now cached - ready for offline use!" -ForegroundColor Green
}
Write-Host "Subsequent runs use cached models (offline capable)" -ForegroundColor Gray
Write-Host ""
