# this script read the https://raw.githubusercontent.com/qliu95114/demystify/refs/heads/main/ps_azure/azurespeed_armlocation.csv
# and this file format is Cloud,Hostname
# script will test url and measure the latency


Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

$pingcount = 10         # Ping the hostname 10 times
$hosts = Import-Csv -Path azurespeed_armlocation.csv
Write-UTCLog "Each Ping Test count $($pingcount)" 
Write-UTCLog "Total hosts: $($hosts.count)" 

$st=Get-Date
# Create a runspace pool for multi-threading
$runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $hosts.count) # Min 1 thread, Max Host.Count threads
$runspacePool.Open()

# Create a list to hold the runspaces
$runspaces = @()

# Loop through each hostname in the CSV
foreach ($h in $hosts) {
    $hostname = $h.Hostname
    $cloud = $h.Cloud

    # Create a new runspace for each host
    $runspace = [PowerShell]::Create()
    $runspace.RunspacePool = $runspacePool

    # Add script to the runspace
    [void]$runspace.AddScript({
        param($hostname,$cloud,$pingcount)

        # Create a Ping object
        $ping = New-Object System.Net.NetworkInformation.Ping

        # Array to store ping results
        $latencies = @()

        for ($i = 0; $i -lt $pingcount; $i++) {  # ping 10 times and cacluate the average for the success result. 
            try {
                $reply = $ping.Send($hostname, 1000) # Timeout of 1000ms
                if ($reply.Status -eq "Success") {
                    $latencies += $reply.RoundtripTime
                }
            } catch {
                # Handle errors (e.g., host unreachable)
            }
        }

        # Calculate the latency statistics for the host
        if ($latencies.Count -gt 0) {
            # Average latency need be in x.xx format two decimal places
            $avgLatency = [math]::Round(($latencies | Measure-Object -Average).Average, 2)
            $maxLatency = ($latencies | Measure-Object -Maximum).Maximum
            $minLatency = ($latencies | Measure-Object -Minimum).Minimum 
        } else {
            $avgLatency = "N/A"
            $maxLatency = "N/A"
            $minLatency = "N/A"
        }

        # Return the result as a custom object
        [PSCustomObject]@{
            Cloud = $cloud
            Hostname = $hostname
            Latency_min = $minLatency
            Latency_max = $maxLatency
            Latency_avg  = $avgLatency
        }
    }).AddArgument($hostname).AddArgument($cloud).AddArgument($pingcount)

    # Start the runspace and add it to the list
    $runspaces += [PSCustomObject]@{
        Runspace = $runspace.BeginInvoke()
        PowerShell = $runspace
    }
}

# Wait for all runspaces to complete and collect results
$results = @()
foreach ($rs in $runspaces) {
    $results += $rs.PowerShell.EndInvoke($rs.Runspace)
}

# Close the runspace pool
$runspacePool.Close()

# Display the results in a nicely formatted table
$results | Sort-Object Latency_min | Format-Table -AutoSize 

if (Test-path $env:temp\azurespeed_armlocation_result.csv) {
    Remove-Item $env:temp\azurespeed_armlocation_result.csv
}
else {
    $results | Sort-Object Latency_min | Export-Csv -Path $env:temp\azurespeed_armlocation_result.csv -NoTypeInformation    <# Action when all if and elseif conditions are false #>
}
$et=Get-Date
$duration = ($et - $st).TotalSeconds
Write-UTCLog "Finished in $($duration) Seconds" 
#notepad++.exe $env:temp\azurespeed_armlocation_result.csv