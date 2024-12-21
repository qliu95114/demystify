# App Launch Redirection Script
#This script is intended for redirecting app launches. It takes the application name as a parameter and uses the `ParentPath` from `applist.csv`. This file contains the folder path pattern for each application.

## Key Steps:
#1. **Validate Application Name:** Ensure that `$appName` is one of the applications listed in the dictionary.
#2. **Launch Application:** Start the application from the most recent folder.

### Additional Notes:

# Ensure `applist.csv` is up-to-date with the correct folder path patterns.
# The script should handle errors gracefully, such as when an application name is not found in the dictionary.
# Consider adding logging for easier troubleshooting and monitoring of app launches.

param(
    [string]$appName
)

#function of write-utclog , take parameter as log message and write it to console add UTC time [] ahead
function Write-UTCLog {
    param(
        [string]$message
    )

    Write-Host ("[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $message)
}

if (-not $appName) {
    Write-UTCLog "Please provide the application name"
    exit
}

#$dictionary = Import-Csv -Path "D:\Kuaipan\AzureDemo\RDP\StoreApp\applist.csv"
$dictionary = Import-Csv -Path "$($PSScriptRoot)\applist.csv"


if (-not $dictionary) {
    Write-UTCLog "Dictionary is empty"
    exit
}

$application = $dictionary | Where-Object { $_.AppName -eq $appName }

Write-UTCLog "Application: $($application.ExeName)"
Write-UTCLog "ParentPath: $($application.ParentPath)"

if (-not $application) {
    Write-UTCLog "Application not found in dictionary"
    exit
}

$latestFolder = Get-ChildItem -Path $application.ParentPath -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-UTCLog "$($latestFolder.FullName)\$($application.ExeName)"
Start-Process -FilePath "$($latestFolder.FullName)\$($application.ExeName)"

#Sleep for 7 seconds display the count down before closing the session
for ($i = 7; $i -gt 0; $i--) {
    Write-UTCLog "Auto Close StoreApp_rdr in $i seconds"
    Start-Sleep -Seconds 1
}
