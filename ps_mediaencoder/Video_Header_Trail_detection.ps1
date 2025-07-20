<#
# use ffmpeg to extract picture of video file , every 1 second 1 picture, filename is the same as video filename_secondsofbeginning.jpg

#>

<#
.SYNOPSIS
Use FFMPG to extract picture of video file

.DESCRIPTION
Use FFMPG to extract picture of video file, every 1 second 1 picture, filename is the same as video filename_secondsofbeginning.jpg

.PARAMETER filename
The name of the file to be converted, please include full path of the file , wildcard is not supported.

.PARAMETER videotemp
The Target folder we will save the extract picture, Default is $env:temp folder

.PARAMETER logfolder
The Log folder we will save the FFMPEG log file, Default is $env:temp folder

.PARAMETER image_start
the image for start

.PARAMETER image_end
the image for end


.EXAMPLE
.\Video_Header_Trail_detection.ps1 -filename G:\DOWNLOADS\transfer\ffmpeg\video.23.1080p.HD.mp4 -videotemp "E:\TV.Asia" -logfolder E:\TV.Asia
#>

Param (
    [Parameter(Mandatory=$true)][string]$filename,
    [string]$image_start,
    [string]$image_end,
    [string]$videotemp="$($env:temp)",
    [string]$logfolder="$($env:temp)"
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
        [array]$imagesToCompare,
        [int]$offset=0  # used to calculate output seconds based on the file name split with _ and remove the extension
    )

    If (!(Test-Path $csvFile)) {
        "Filename,Offset,RMSE,MAE,PSNR" | Out-File -FilePath $csvFile -Encoding UTF8
    }

    Write-Host "Comparing images with reference image: $referenceImage" -ForegroundColor Gray
    foreach ($image in $imagesToCompare) {
        $RMSE_result = magick compare -metric RMSE "$referenceImage" "$($image.FullName)" null: 2>&1
        $RMSE_value = [regex]::Match($RMSE_result, '\d+(\.\d+)?').Value
        $csvLine = "$($image.Name),$offset,$RMSE_value,,"

        #Write-UTCLog "Comparing $($image.Name) with $($referenceImage) : RMSE: $($RMSE_value) " "Gray"
        Write-Host "." -NoNewline -ForegroundColor Gray
        $csvLine | Out-File -FilePath $csvFile -Append -Encoding UTF8

        If ([int]$RMSE_value -lt 5000) {
            # calaculate output seconds based on the file name split with _ and remove the extension
            $seconds = [int]($image.BaseName -split '_')[1] + $offset
            Write-Host "." -ForegroundColor Gray
            Write-UTCLog "Found a match for $($image.Name) with RMSE: $($RMSE_value), exiting loop, output seconds: $seconds" "Cyan"
            # copy file to log folder
            $image | Copy-Item -Destination "$logfolder\$($image.BaseName.split('_')[0])_$seconds.png" -Force
            return $true,$seconds

        }
    }
    return $false,0
}

If ((Test-Path $filename) -and (Test-Path $videotemp))
{



    # csvfile is using $filename base name with .csv extension and remove all path + $logfolder 
    $csvFile = "$($logfolder.TrimEnd('\'))\$((Get-Item $filename).BaseName).csv"
    #get video duration 
    $duration=ffprobe ""$($filename)"" -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -v error
    $duration= [int]$duration
    Write-UTCLog "Start to extract picture of $($filename) (duration: $duration seconds) and save to $($videotemp)" "Cyan"
    If ($duration -lt 300)
    {
        Write-UTCLog "Video duration is less than 300 seconds, no picture will be extracted" "Red"
        return
    }

    # create output folder if not exist
    If (!(Test-Path $videotemp))
    {
        New-Item -Path $videotemp -ItemType Directory | Out-Null
        Write-UTCLog "Created output folder: $($videotemp)" "Green"
    }

    # generate output png files every 1 second 1 file , header processing...
    $outputFilePattern = Join-Path -Path $videotemp -ChildPath "$((Get-Item $filename).BaseName)_%d.png"

    #clean up output folder
    Write-UTCLog "Cleaning up output folder: $($videotemp)" "Yellow"
    Get-ChildItem -Path $videotemp -Filter "$((Get-Item $filename).BaseName)_*.png" | Remove-Item -Force -ErrorAction SilentlyContinue

    $ffmpeg = "ffmpeg.exe"
    $ffmpegArgs = "-ss 0 -to 300 -i `"$filename`" -vf fps=1 `"$outputFilePattern`" "  # extract 300 seconds of video, 1 frame per second
    Write-UTCLog "Running ffmpeg with args: $ffmpegArgs" "Green"
    $process = Invoke-Expression "$ffmpeg $ffmpegArgs 2> `"$logfolder\$((Get-Item $filename).BaseName)_ffmpeg_start.log`""
    #$process = Start-Process -FilePath $ffmpeg -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
     # valid target folder has 300 png file 
    $pCount=(Get-ChildItem -Path $videotemp -Filter "$((Get-Item $filename).BaseName)_*.png").Count
    if ($pCount -ge 300)
    {
        Write-UTCLog "Video 2 Picture (0-300) extraction completed successfully" "Green"
    }
    else
    {
        Write-UTCLog "Video 2 Picture (0-300) extraction failed with exit code $($process.ExitCode), only see $pCount files" "Red"
    }

    If ($image_start -and (Test-Path $image_start))
    {
        Write-UTCLog "image_start ($image_start), proceeding with comparison" "Green"
        # Compare start images
        $startImages = Get-ChildItem -Path $videotemp -Filter "$((Get-Item $filename).BaseName)_*.png" | 
            Sort-Object LastWriteTime | 
            Select-Object -First 300
        $startdetect,$startsec =Compare-Images -referenceImage $image_start -csvFile $csvFile -imagesToCompare $startImages
    }
    Else
    {
        Write-UTCLog "No valid image_start provided, skipping comparison" "Red"
        $image_start = $null
    }

    # only if $image_start is not empty, we will proceed to extract the end images, because I assume when user does not provide $image_start, they want to extract the end images only
    if ($image_start -eq '')
    {
    }
    else {
        Write-UTCLog "No image_start provided, extracting end images " "Green"
        Get-ChildItem -Path $videotemp -Filter "$((Get-Item $filename).BaseName)_*.png" | Remove-Item -Force -ErrorAction SilentlyContinue
    }


    $ffmpeg = "ffmpeg.exe"

    $ffmpegArgs = "-ss $($duration-300) -to $duration -i `"$filename`" -vf fps=1 `"$outputFilePattern`" "  # extract 300 seconds of video, 1 frame per second
    Write-UTCLog "Running ffmpeg with args: $ffmpegArgs" "Green"
    $process = Invoke-Expression "$ffmpeg $ffmpegArgs 2> `"$logfolder\$([System.IO.Path]::GetFileNameWithoutExtension($filename))_ffmpeg_end.log`""
    #$process = Start-Process -FilePath $ffmpeg -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru
    # valid target folder has 300 png file 
    $pCount=(Get-ChildItem -Path $videotemp -Filter "$((Get-Item $filename).BaseName)_*.png").Count
    if ($pCount -ge 300)
    {
        Write-UTCLog "Video 2 Picture ($($duration-300)-$duration) extraction completed successfully" "Green"
    }
    else
    {
        Write-UTCLog "Video 2 Picture ($($duration-300)-$duration) extraction failed with exit code $($process.ExitCode), only see $pCount files" "Red"
    }

    If ($image_end -and (Test-Path $image_end))
    {
        Write-UTCLog "image_end ($image_end), proceeding with comparison" "Green"
        # Compare end images
        $endImages = Get-ChildItem -Path $videotemp -Filter "$((Get-Item $filename).BaseName)_*.png" | 
            Sort-Object LastWriteTime | 
            Select-Object -Last 300
        $enddetect,$endsecs =Compare-Images -referenceImage $image_end -csvFile $csvFile -imagesToCompare $endImages -offset $($duration-300)
    }
    Else
    {
        Write-UTCLog "No valid image_end provided, skipping comparison" "Red"
        $image_end = $null
    }

    # only if $image_start is not empty, we will proceed to extract the end images, because I assume when user does not provide $image_start, they want to extract the end images only
    if ($image_end -eq '')
    {
    }
    else {
        Write-UTCLog "No image_end provided, extracting end images " "Green"
        Get-ChildItem -Path $videotemp -Filter "$((Get-Item $filename).BaseName)_*.png" | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}
else
{
    Write-UTCLog "File $($filename) or Folder $($videotemp) does not exist, please recheck"  "Red"
}

# print out the summary
if ($startdetect -and $enddetect)
{
    Write-UTCLog "========================================================================================" "Yellow"
    Write-UTCLog "Start image detected at $($startsec) seconds, End image detected at $($endsecs) seconds, $($duration - $endsecs)" "Yellow"
    Write-UTCLog "========================================================================================" "Yellow"
}
else
{
    Write-UTCLog "No matching images found for start or end detection" "Red"
}