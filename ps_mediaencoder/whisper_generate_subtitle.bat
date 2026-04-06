@echo off
REM Whisper Subtitle Generator - Windows Batch Wrapper
REM Usage: Drag and drop a video/audio file onto this batch file
REM Or run: whisper_generate_subtitle.bat "path\to\video.mp4" [model]

setlocal

if "%~1"=="" (
    echo.
    echo Whisper Subtitle Generator
    echo ==========================
    echo.
    echo Usage: Drag and drop a video/audio file onto this batch file
    echo Or run: whisper_generate_subtitle.bat "path\to\video.mp4" [model]
    echo.
    echo Models: tiny, base, small, medium, large-v3
    echo Default: medium
    echo.
    echo Example:
    echo   whisper_generate_subtitle.bat "D:\Videos\video.mp4"
    echo   whisper_generate_subtitle.bat "D:\Videos\video.mp4" large-v3
    echo.
    pause
    exit /b 1
)

set "VIDEO_FILE=%~1"
set "MODEL=%~2"

if "%MODEL%"=="" set "MODEL=medium"

echo.
echo ========================================
echo Whisper Subtitle Generator
echo ========================================
echo Input: %VIDEO_FILE%
echo Model: %MODEL%
echo ========================================
echo.

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

REM Run the Python script
python "%SCRIPT_DIR%whisper_subtitle_generator.py" "%VIDEO_FILE%" "%MODEL%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Transcription failed!
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Transcription Complete!
echo ========================================
echo.
echo Subtitle files have been saved to the same directory as your video.
echo.
pause
