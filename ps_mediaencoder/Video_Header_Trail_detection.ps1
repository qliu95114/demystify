<#
# use ffmpeg to extract picture of video file , every 1 second 1 picture, filename is the same as video filename_secondsofbeginning.jpg

#>

<#
.SYNOPSIS
Use FFMPG to extract picture of video file

.DESCRIPTION
Use FFMPG to extract picture of video file, every 1 second 1 picture, filename is the same as video filename_secondsofbeginning.jpg

.PARAMETER filename
The name of the file to be converted, please include full path of the file , wildchar is not supported. 

.PARAMETER outputfolder
The Target folder we will save the cutted file, Default \\192.168.3.17\g$\DOWNLOADS\transfer\ffmpeg

.PARAMETER logfolder
The Log folder we will save the FFMPEG log file, Default \\192.168.3.17\g$\DOWNLOADS\ffmpeg_log\cut

.PARAMETER image_start
the image for start

.PARAMETER image_end
the image for end


.EXAMPLE
.\Video_Header_Trail_detection.ps1 -filename G:\DOWNLOADS\transfer\ffmpeg\video.23.1080p.HD.mp4 -outputfolder "E:\TV.Asia" -logfolder E:\TV.Asia
#>

Param (
    [Parameter(Mandatory=$true)][string]$filename,
    [string]$image_start,
    [string]$image_end,
    [string]$outputfolder="\\192.168.3.17\g$\DOWNLOADS\transfer\ffmpeg",
    [string]$logfolder="\\192.168.3.17\g$\DOWNLOADS\ffmpeg_log\cut",
    [switch]$skip=$false
)

Function Write-UTCLog ([string]$message,[string]$color="green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

# Create function to compare images and generate CSV
function Compare-Images {
    param(
        [string]$referenceImage,
        [string]$csvFile,
        [array]$imagesToCompare
    )

    If (!(Test-Path $csvFile)) {
        "Filename,RMSE,MAE,PSNR" | Out-File -FilePath $csvFile -Encoding UTF8
    }

    foreach ($image in $imagesToCompare) {
        $RMSE_result = magick compare -metric RMSE "$referenceImage" "$($image.FullName)" null: 2>&1
        $RMSE_value = [regex]::Match($RMSE_result, '\d+(\.\d+)?').Value
        $csvLine = "$($image.Name),$RMSE_value,,"

        Write-UTCLog "Comparing $($image.Name) with $($referenceImage) : RMSE: $($RMSE_value) " "Gray"
        $csvLine | Out-File -FilePath $csvFile -Append -Encoding UTF8

        If ([int]$RMSE_value -lt 5000) {
            Write-UTCLog "Found a match for $($image.Name) with RMSE: $($RMSE_value), exiting loop" "Cyan"
            return $true
        }
    }
    return $false
}

If ((Test-Path $filename) -and (Test-Path $outputfolder) -and ($skip -eq $false))
{

    Write-UTCLog "Start to extract picture of of $($filename) and save to $($outputfolder)" "Green"

    #get video duration 
    $duration=ffprobe ""$($filename)"" -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -v error
    Write-UTCLog "Video duration is $duration seconds" "Green"
    If ($duration -lt 1)
    {
        Write-UTCLog "Video duration is less than 1 second, no picture will be extracted" "Red"
        return
    }

    # create output folder if not exist
    If (!(Test-Path $outputfolder))
    {
        New-Item -Path $outputfolder -ItemType Directory | Out-Null
        Write-UTCLog "Created output folder: $($outputfolder)" "Green"
    }

    # generate output png files every 1 second 1 file
    $outputFilePattern = Join-Path -Path $outputfolder -ChildPath "$((Get-Item $filename).BaseName)_%d.png"
    $ffmpeg = "ffmpeg.exe"
    $ffmpegArgs = "-i `"$filename`" -vf fps=1 `"$outputFilePattern`""
    Write-UTCLog "Running ffmpeg with args: $ffmpegArgs" "Green"
    $process = Start-Process -FilePath $ffmpeg -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
    If ($process.ExitCode -eq 0)
    {
        Write-UTCLog "Picture extraction completed successfully" "Green"
    }
    else
    {
        Write-UTCLog "Picture extraction failed with exit code $($process.ExitCode)" "Red"
    }

}
else
{
    Write-UTCLog "File $($filename) or Folder $($outputfolder) does not exist, please recheck"  "Red"
}

# if image_start and image_end are provided, use magick to compare the image_start and image_end with each extracted image and output the result of comparison, 
# if the image_start and image_end are not provided, just output the extracted images
If ($image_start -and $image_end)
{
    # Compare start images
    $csvFile_start = "$($image_start).csv"
    Write-UTCLog "StartCSV file: $csvFile_start" "Green"
    $startImages = Get-ChildItem -Path $outputfolder -Filter "$((Get-Item $filename).BaseName)_*.png" | 
        Sort-Object LastWriteTime | 
        Select-Object -First 300
    Compare-Images -referenceImage $image_start -csvFile $csvFile_start -imagesToCompare $startImages

    # Compare end images
    $csvFile_end = "$($image_end).csv"
    Write-UTCLog "EndCSV file: $csvFile_end" "Green"
    $endImages = Get-ChildItem -Path $outputfolder -Filter "$((Get-Item $filename).BaseName)_*.png" | 
        Sort-Object LastWriteTime | 
        Select-Object -Last 300
    Compare-Images -referenceImage $image_end -csvFile $csvFile_end -imagesToCompare $endImages
}
else {
    Write-UTCLog "No valid images found for comparison" "Red"
}