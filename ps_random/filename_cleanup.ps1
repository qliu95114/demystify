<#
.SYNOPSIS
# This script will batch handle filenames under one folder 

.DESCRIPTION
This script cleans up the [anything] from the filename. It can:
a. Remove [ ] from the filename.
b. Remove a specific string.
c. Add a prefix to the filename.

.PARAMETER folder
The source folder where the files are located.

.PARAMETER str2remove
The string to remove from the filename.

.PARAMETER str2prefixadd
The string to add to the filename.

.PARAMETER str2replace_source

.PARAMETER str2replace_dest

.EXAMPLE

.NOTES
Author: qliu
Date: 2025-01-12, first version
#>

# Powershell Function Write-UTCLog , 2024-04-12

Param(
    [string]$folder,
    [string]$str2remove,
    [string]$str2prefixadd,
    [string]$str2replace_source,
    [string]$str2replace_dest
)

Function Write-UTCLog ([string]$message, [string]$color = "white") {
    $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    $logstamp = "[" + $logdate + "]," + $message
    Write-Host $logstamp -ForegroundColor $color
}

# remove the [any] from the filename
$files = Get-ChildItem $folder -File 

foreach ($file in $files) {
    $newName = $file.Name -replace '\[.*\]', ''
    $newPath = Join-Path $file.DirectoryName $newName
    Rename-Item -LiteralPath $file.FullName -NewName $newPath
    Write-UTCLog "Remove `[`] $($file.FullName) to $newPath"
}

# if $str2remove is not empty then take out [any] 
if ([string]::IsNullOrEmpty($str2remove)) {
    Write-UTCLog "Remove '$str2remove' is empty, skip" -color "yellow"
}
else {
    # remove the str2remove from the filename
    $files = Get-ChildItem $folder -File 
    foreach ($file in $files) {
        $newName = $file.Name -replace $str2remove, ''
        $newPath = Join-Path $file.DirectoryName $newName
        Rename-Item -LiteralPath $file.FullName -NewName $newPath
        Write-UTCLog "Remove '$str2remove' $($file.FullName) to $newPath"
    }
}

#if $str2prefixadd is not empty then add the str2prefixadd to the filename
if ([string]::IsNullOrEmpty($str2prefixadd)) {
    Write-UTCLog "Add '$str2prefixadd' is empty, skip" -color "yellow"
}
else {
    # add the str2prefixadd to the filename
    $files = Get-ChildItem $folder -File
    foreach ($file in $files) {
        $newName = $str2prefixadd + $file.Name
        $newPath = Join-Path $file.DirectoryName $newName
        Rename-Item -LiteralPath $file.FullName -NewName $newPath
        Write-UTCLog "Add '$str2prefixadd' $($file.FullName) to $newPath"
    }
}

# if $str2replace_source & $str2replace_dest is not empty then replace the str2replace_source to str2replace_dest
if ([string]::IsNullOrEmpty($str2replace_source) -or [string]::IsNullOrEmpty($str2replace_dest)) {
    Write-UTCLog "Replace '$str2replace_source' to '$str2replace_dest' is empty, skip" -color "yellow"
}
else {
    # replace the str2replace_source to str2replace_dest
    $files = Get-ChildItem $folder -File
    foreach ($file in $files) {
        $newName = $file.Name -replace $str2replace_source, $str2replace_dest
        $newPath = Join-Path $file.DirectoryName $newName
        Rename-Item -LiteralPath $file.FullName -NewName $newPath
        Write-UTCLog "Replace '$str2replace_source' to '$str2replace_dest' $($file.FullName) to $newPath"
    }
}