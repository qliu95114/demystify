
<# Overview: 
This script monitors the health of backend pool instances in an Azure Load Balancer using `pingmon.exe`.
## Key Points:
1. **Baseline Configuration**:
   - When the script starts, it reads the backend pool configuration as the baseline for all backend network interfaces.
   - Any backend IPs not part of the backend pool at startup will not be monitored.

2. **Assumptions**:
   - Each backend VM is assumed to have only one IP address on its network interface.

Kudo's to https://sourceforge.net/projects/pingmon-win/
provide a simple ICMP monitoring tool "pingmon.exe" for Windows. and this script leverage the multi-target ping monitoring feature of pingmon.exe 

#>

# Import required modules
Import-Module Az.Accounts
Import-Module Az.Network

<# azurelb_monitor.json configuration sample format
{
    "servicePrincipalName": "your-service-principal-name",
    "servicePrincipalSecret": "your-service-principal-secret",
    "tenantId": "your-tenant-id",
    "cloudEnvironment": "AzureCloud",
    "subscriptionId": "your-subscription-id",
    "loadBalancerResourceUri": "/subscriptions/your-subscription-id/resourceGroups/your-resource-group/providers/Microsoft.Network/loadBalancers/your-load-balancer-name",
    "loadBalancerPoolName": "your-backend-pool-name",
    "icmpIntervalinMS": 1000,
    "Unhealthythreshold": 3,
    "healthythreshold": 5,
    "logFilePath": "D:\\loadBalancerMonitor.log"
}#>

# Define the path to the JSON configuration file
$jsonFilePath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "azurelb_monitor.json"

# Read the JSON configuration file
$config = Get-Content -Path $jsonFilePath | ConvertFrom-Json

# Extract configuration details
$servicePrincipalName = $config.servicePrincipalName
$servicePrincipalSecret = $config.servicePrincipalSecret
$tenantId = $config.tenantId
$cloudEnvironment = $config.cloudEnvironment
$subscriptionId = $config.subscriptionId
$loadBalancerResourceUri = $config.loadBalancerResourceUri
$icmpIntervalinMS = $config.icmpIntervalinMS
$unhealthythreshold = $config.Unhealthythreshold
$healthythreshold = $config.healthythreshold
$logFilePath = $config.logFilePath
$poolName = $config.loadBalancerPoolName

# Function to log messages
function Log-Message {
    param (
        [string]$Message
    )
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    Write-Output "[$timestamp] - $Message"
    Add-Content -Path $logFilePath -Value "[$timestamp] - $Message" -Encoding UTF8  
}

# test pingmon.exe available in current folder 
$pingmonPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "pingmon.exe"
if (-not (Test-Path -Path $pingmonPath)) {
    Log-Message "pingmon.exe not found in the script directory. Exiting."
    exit 1
}

# get settings.ini path and locate data folder of pingmon
$settingsIniPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "settings.ini"
if (-not (Test-Path -Path $settingsIniPath)) {
    Log-Message "settings.ini not found in the script directory. Exiting."
    exit 1
}
else {
    #settings.ini locate [Log] section to get DataFolder
    $settingsContent = Get-Content -Path $settingsIniPath
    $dataFolder = ""
    $inLogSection = $false
    foreach ($line in $settingsContent) {  
        if ($line -match '^\[Log\]') {
            $inLogSection = $true
        } elseif ($line -match '^\[') {
            $inLogSection = $false
        } elseif ($inLogSection -and $line -match '^Path=(.+)$') {
            $dataFolder = $Matches[1].Trim()
            break
        }
    }
    if ($dataFolder -eq "") {
        Log-Message "PingMon DataFolder not found in settings.ini. Exiting."
        exit 1
    } else {
        Log-Message "PingMon DataFolder located: $dataFolder"
    }

    # update icmp interval in settings.ini PingEveryMs=1000
    $updatedSettings = $settingsContent | ForEach-Object {
        if ($_ -match '^PingEveryMs=') {
            "PingEveryMs=$icmpIntervalinMS"
        } else {
            $_
        }
    }
    Set-Content -Path $settingsIniPath -Value $updatedSettings -Encoding UTF8
}

# clean up all pingmon process before started 
Get-Process -Name "pingmon" -ErrorAction SilentlyContinue | ForEach-Object {
    Log-Message "Stopping existing pingmon process with ID: $($_.Id)"   
    $_ | Stop-Process -Force
}

# Check if the current Azure context matches the desired subscription ID
$currentContext = Get-AzContext

if ($currentContext.Subscription.Id -ne $subscriptionId) {
    # Login to Azure
    Log-Message "Logging in to Azure..."
    Connect-AzAccount -ServicePrincipal -Credential (New-Object System.Management.Automation.PSCredential($servicePrincipalName, (ConvertTo-SecureString $servicePrincipalSecret -AsPlainText -Force))) -TenantId $tenantId -Environment $cloudEnvironment
    Set-AzContext -SubscriptionId $subscriptionId
    Log-Message "Login successful."
} else {
    Log-Message "Already logged in with the correct subscription context. $subscriptionId"
}

# Verify Load Balancer existence and list backend poolsdir
$backendpool= Get-AzLoadBalancerBackendAddressPool -ResourceGroupName ($loadBalancerResourceUri.split('/')[4]) -LoadBalancerName ($loadBalancerResourceUri.split('/')[8]) -Name $poolName
if ($backendpool -eq $null) {
    Log-Message "Load Balancer or Backend Pool not found. Exiting."
    exit 1
} else {
    Log-Message "Load Balancer and Backend Pool found: $($backendpool.Name)"
}

# Initialize state tracking for backend IPs
$backendState = @{}
$totalipes=""

foreach ($backend in $backendPool.LoadBalancerBackendAddresses.NetworkInterfaceIpConfiguration) {
        # Extract the NIC configuration from the backend IP configuration ID
        $nicId = $backend.id -replace '/ipConfigurations/.*$', ''
        $nic = Get-AzNetworkInterface -ResourceId $nicId
        $targetIp = $nic.IpConfigurations | Where-Object { $_.Id -eq $backend.id } | Select-Object -ExpandProperty PrivateIpAddress

        if (-not $backendState.ContainsKey($targetIp)) {
            $backendState[$targetIp] = @{
                UnhealthyCount = 0
                HealthyCount = 0
                IsRemoved = $false
                nicResourceId = $nicId
                ipConfigurationsId = $backend.id
            }
        }
        Log-Message "Find target IP: $targetIp in backend pool: $($backendPool.name)"
        Log-Message "NIC Resource ID: $nicId"
        $totalip+=$targetIp+" " 
    }
Log-Message "Total target IPs to monitor: $totalip"
Start-Process -FilePath $pingmonPath -ArgumentList $totalip -NoNewWindow    

#only continue if we have pingmon started
if ((Get-Process -Name "pingmon" -ErrorAction SilentlyContinue) -eq $null) {
    Log-Message "pingmon process not started. Exiting."
    exit 1
}

# add sleep delay max("Unhealthythreshold": healthythreshold") before start to monitor
$maxThreshold = [Math]::Max($unhealthythreshold, $healthythreshold)
Log-Message "Waiting for $($maxThreshold * $icmpIntervalinMS) milliseconds to allow pingmon to gather initial data..."
Start-Sleep -Milliseconds ($maxThreshold * $icmpIntervalinMS)

# under DataFolder, pingmon create log files named by %ip%.dat, monitor those files every 1 seconds
# file content is yyyymmddhhmmss;[latency in ms], if ping failed, latency is "-1"
while ($true) {
    foreach ($targetIp in $backendState.Keys) {
        $logFile = Join-Path -Path $dataFolder -ChildPath "$targetIp.dat"
        if (Test-Path -Path $logFile) {
            # Read the last max(unhealthythreshold, healthythreshold) lines
            $tailCount = [Math]::Max($unhealthythreshold, $healthythreshold)
            $logLines = Get-Content -Path $logFile -Tail $tailCount

            # Check for unhealthy: last $unhealthythreshold lines are all failed (-1)
            $unhealthyLines = $logLines | Select-Object -Last $unhealthythreshold
            $allUnhealthy = $unhealthyLines.Count -ge $unhealthythreshold -and ($unhealthyLines | Where-Object { $_ -match "^-?\d+;(-?\d+)$" -and $Matches[1] -eq "-1" }).Count -eq $unhealthythreshold

            # Check for healthy: last $healthythreshold lines are all successful (>=0)
            $healthyLines = $logLines | Select-Object -Last $healthythreshold
            $allHealthy = $healthyLines.Count -ge $healthythreshold -and ($healthyLines | Where-Object { $_ -match "^-?\d+;(-?\d+)$" -and [int]$Matches[1] -ge 0 }).Count -eq $healthythreshold

            # Print out the latest result
            $latestLine = $logLines | Select-Object -Last 1
            if ($latestLine -match "^(?<timestamp>\d+);(?<latency>-?\d+)$") {
                $timestamp = $Matches['timestamp']
                $latency = $Matches['latency']
                Log-Message "$targetIp - Last check: $timestamp, Latency: $latency ms"
            }

            if ($allUnhealthy -and -not $backendState[$targetIp].IsRemoved) {
                Log-Message "Target IP $targetIp is unhealthy for $unhealthythreshold consecutive checks. Removing from Load Balancer."
                # Remove logic here if needed
                $backendState[$targetIp].IsRemoved = $true
                # to remove the unhealthy backend from load balancer, we need update nic resource uri's LoadBalancerBackendAddressPools property
                $nic=Get-AzNetworkInterface -ResourceId $backendState[$targetIp].nicResourceId
                $nic.IpConfigurations[0].LoadBalancerBackendAddressPools = $null
                Set-AzNetworkInterface -NetworkInterface $nic -ErrorAction SilentlyContinue

            } elseif ($allHealthy -and $backendState[$targetIp].IsRemoved) {
                Log-Message "Target IP $targetIp is healthy for $healthythreshold consecutive checks. Re-adding to Load Balancer."
                # Re-add logic here if needed
                $backendState[$targetIp].IsRemoved = $false
                # to add the healthy backend back to load balancer, we need update nic resource uri's LoadBalancerBackendAddressPools property
                $bp = Get-AzLoadBalancerBackendAddressPool -ResourceGroupName ($loadBalancerResourceUri.split('/')[4]) -LoadBalancerName ($loadBalancerResourceUri.split('/')[8]) -Name $poolName
                $nic=Get-AzNetworkInterface -ResourceId $backendState[$targetIp].nicResourceId 
                $nic.IpConfigurations[0].LoadBalancerBackendAddressPools = $bp
                Set-AzNetworkInterface -NetworkInterface $nic -ErrorAction SilentlyContinue
            }
        } else {
            Log-Message "Log file for target IP $targetIp not found: $logFile"
        }
    }
    Start-Sleep -Milliseconds $icmpIntervalinMS
}

