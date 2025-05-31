# this powershell will extract all surface update file from msi to one folder. 

# Parameter define the filename to split. 
Param(
    [string]$path=$((Get-Location).path),
    [string]$outputfolder=$((Get-Location).path+'\decompress')
)

function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

# Get all msi files in the path
$msifiles = Get-ChildItem -Path $path -Filter *.msi -Recurse
if ($msifiles.Count -eq 0) {
    Write-UTCLog "No msi files found in the specified path: $path" -color "Red"
    exit
}

Write-UTCLog "Found $($msifiles.Count) msi files in the specified path: $path" -color "Green"

# if the output folder does not exist, create it
if (-not (Test-Path -Path $outputfolder)) {
    New-Item -Path $outputfolder -ItemType Directory | Out-Null
    Write-UTCLog "Created output folder: $outputfolder" -color "Green"
} else {
    Write-UTCLog "Output folder already exists: $outputfolder" -color "Yellow"
}

# Loop through each msi file and extract the surface update files
$i=1
foreach ($msi in $msifiles) {
    Write-UTCLog "$i/ $($msifiles.Count) : Processing msi file: $($msi.FullName)" -color "Cyan"
    try {
        # Use msiexec to extract the files
        $output = Start-Process -FilePath "msiexec.exe" -ArgumentList "/a `"$($msi.FullName)`" /qb TARGETDIR=`"$outputfolder`"" -NoNewWindow -Wait -PassThru
        if ($output.ExitCode -eq 0) {
            Write-UTCLog "Successfully extracted files from: $($msi.FullName)" -color "Green"
        } else {
            Write-UTCLog "Failed to extract files from: $($msi.FullName). Exit code: $($output.ExitCode)" -color "Red"
        }
    } catch {
        Write-UTCLog "Error processing msi file: $($msi.FullName). Error: $_" -color "Red"
    }
    $i++
}



