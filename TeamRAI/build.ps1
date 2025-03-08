# this is script create a zip file of current folder 
# it take a paramenter of the zip file name

param (
    [string]$zipFileName="$($env:temp)\TeamRAI.zip"
)

function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

# check target file exist and prompt user need to overwrite 
if (Test-Path $zipFileName) {
    $overwrite = Read-Host "The file $zipFileName already exists. Do you want to overwrite it? (y/n)"
    if ($overwrite -ne 'y') {
        Write-UTCLog "Operation cancelled by user."  -color "red"
        exit
    }
    else {
        Remove-Item -Path $zipFileName -Force
        Write-UTCLog "Existing file $zipFileName removed." -color "yellow"
    }
}

# Create a temporary directory for the zip file
$tempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString()))

# Copy the contents of the current directory to the temporary directory
Get-ChildItem -Path . -Recurse | Copy-Item -Destination $tempDir.FullName -Recurse

# Create the zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir.FullName, $zipFileName)

Write-UTCLog "Zip file created at $zipFileName"  -color "cyan"
# Clean up the temporary directory
Remove-Item -Path $tempDir.FullName -Recurse -Force