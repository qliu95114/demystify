# this script is clean up azure blob container file with specific file extension

# .SYNOPSIS
# # this script will clean up the azure blob container file with specific file extension
#
# .DESCRIPTION
# This script is used to clean up the azure blob container file with specific file extension
# This script will read the azure blob container and list all the files with specific file extension

# The script will delete all the files from azure blob container with specific file extension
# The script will log the event to Azure Application Insights and keep the result in log file folder_replica_log.txt

# .PARAMETER storageaccountname
# Azure Blob Container name to clean up

# .PARAMETER containername
# Azure Blob Container name to clean up

# .PARAMETER fileextension
# File extension to clean up

# .EXAMPLE
# replication d:\folder2 d:\folder1 12345678-1234-1234-1234-123456789012
# .\blob_container_cleanup.ps1 -containername mycontainer -fileextension .txt -storageaccountname mystorageaccount

# .NOTES

Param(
    [Parameter(Mandatory=$true)][string]$storageaccountname,
    [Parameter(Mandatory=$true)][string]$containername,
    [string]$fileextension=".csv"
)

# Powershell Function Write-UTCLog , 2024-04-12
Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

# main function 
# powershell to get blob file from container & storage account

if ([string]::IsNullOrEmpty($storageaccountname)){
    Write-UTCLog "No storage account name found" "Red"
    exit
}
else {
    Write-UTCLog "storage account name : $($storageaccountname)" "Green"
}

if ([string]::IsNullOrEmpty($containername)){
    Write-UTCLog "No container name found" "Red"
    exit
}
else {
    Write-UTCLog "container name : $($containername)" "Green"
}

if ([string]::IsNullOrEmpty($fileextension)){
    Write-UTCLog "No file extension found" "Red"
    exit
}
else {
    Write-UTCLog "file extension : $($fileextension)" "Green"
}

$storageaccountkey=(az storage account keys list --account-name $storageaccountname --query "[0].value" -o tsv) 
if ([string]::IsNullOrEmpty($storageaccountkey)){
    Write-UTCLog "No storage account key found for $storageaccountname" "Red"
    exit
}
else {
    Write-UTCLog "storage account key get success key length: $($storageaccountkey.length)" "Green"
}

$ctx = New-AzStorageContext -StorageAccountName $storageaccountname -StorageAccountKey $storageaccountkey
Write-UTCLog "Get Total Blob files from SA: $($storageaccountname) Container: $($containername)" "Green"
$blobs = Get-AzStorageBlob -Container $containername -Context $ctx
Write-UTCLog "Total files in $($containername): $($blobs.Count)" "Cyan"
$i=1
Write-UTCLog "Azure Blob Container $containername clean up started" "Green"
$blobs | ForEach-Object {
    if ($_.Name -like "*$fileextension") {
        Write-UTCLog "$($i) matches/ $($blobs.Count) : Deleting $($containername)/$($_.Name) " "Yellow"
        Remove-AzStorageBlob -Blob $_.Name -Container $containername -Context $ctx
        $i++
    }
}
Write-UTCLog "Azure Blob Container $containername clean up completed" "Green"


