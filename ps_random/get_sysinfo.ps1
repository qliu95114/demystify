# Collect CPU type information
$cpuInfo = Get-CimInstance -ClassName Win32_Processor | Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors

# Collect Memory size information (in GB)
$memoryInfo = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object @{Name='TotalPhysicalMemory(GB)'; Expression={"{0:N2}" -f ($_.TotalPhysicalMemory / 1GB)}}

# Collect Disk type and size information
$diskInfo = Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Model, MediaType, @{Name='Size(GB)'; Expression={"{0:N2}" -f ($_.Size / 1GB)}}

# Output the collected information
Write-Host "CPU Information:"
$cpuInfo | Format-Table -AutoSize

Write-Host "`nMemory Information:"
$memoryInfo | Format-Table -AutoSize

Write-Host "`nDisk Information:"
$diskInfo | Format-Table -AutoSize