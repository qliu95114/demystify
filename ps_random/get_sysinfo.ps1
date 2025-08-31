[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName
)

# Test if the remote computer is accessible
if (-not (Test-Connection -ComputerName $ComputerName -Quiet -Count 1)) {
    Write-Error "Cannot connect to remote computer: $ComputerName"
    return
}

# collect system model and service tag information and asset number
$systemInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName | 
    Select-Object Model, Manufacturer 

# Collect CPU type information
$cpuInfo = Get-CimInstance -ClassName Win32_Processor -ComputerName $ComputerName | 
    Select-Object Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors

# Collect Memory size information (in GB)
$memoryInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName | 
    Select-Object @{Name='TotalPhysicalMemory(GB)'; Expression={"{0:N2}" -f ($_.TotalPhysicalMemory / 1GB)}}

# Collect Disk type and size information
$diskInfo = Get-CimInstance -ClassName Win32_DiskDrive -ComputerName $ComputerName | 
    Select-Object Model, MediaType, @{Name='Size(GB)'; Expression={"{0:N2}" -f ($_.Size / 1GB)}} | Sort-Object Model

# Output the collected information
Write-Host "System Information for computer: $ComputerName"
Write-Host "-----------------------------------------"

Write-Host "`nSystem Information:"
$systemInfo | Format-Table -AutoSize

Write-Host "`nCPU Information:"
$cpuInfo | Format-Table -AutoSize

Write-Host "`nMemory Information:"
$memoryInfo | Format-Table -AutoSize

Write-Host "`nDisk Information:"
$diskInfo | Format-Table -AutoSize