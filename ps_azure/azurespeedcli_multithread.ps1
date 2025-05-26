# this script read the https://raw.githubusercontent.com/qliu95114/demystify/refs/heads/main/ps_azure/azurespeed_armlocation.csv
# and this file format is Cloud,Hostname
# script will test url and measure the latency

# Parameter help description
Param(
    [string]$csvfile="$PSScriptRoot\azurespeed_armlocation.csv",
    [int]$pingcount=10
)

Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

# test if the file exists in the current directory, if not, download it from the URL
if (Test-Path $csvfile) {
    Write-UTCLog "File $($csvfile) exists." "Green"
} else {
    Write-UTCLog "File $($csvfile) does not exist. Downloading from URL..." "Yellow"
    $url = "https://raw.githubusercontent.com/qliu95114/demystify/refs/heads/main/ps_azure/azurespeed_armlocation.csv"
    Invoke-WebRequest -Uri $url -OutFile "$env:temp\\azurespeed_armlocation.csv"
    $csvfile="$env:temp\\azurespeed_armlocation.csv"
    Write-UTCLog "File downloaded to $($csvfile)" "Green"
}
$hosts = Import-Csv -Path $csvfile
Write-UTCLog "PingTest Count : $($pingcount)" 
Write-UTCLog "DomainName (total): $($hosts.count)" 

$st=Get-Date
# Create a runspace pool for multi-threading
$maxThreads = [math]::Min([int]((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors /2) , $hosts.count)
Write-UTCLog "Threads (total): $maxThreads"
$runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads) # Min 1 thread, Max calculated threads
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

        # Get the IP address of the host, retry 3 times if failed
        $ip = ""
        for ($j = 0; $j -lt 10; $j++) {
                #$iplist=(Resolve-DnsName $hostname).IPAddress
                $iplist=(Resolve-DnsName $hostname).IP4Address
                $ip=$iplist.split(',')[0]
                if ("" -ne $ip) 
                {
                    break
                }
                else {
                    start-sleep -Milliseconds 50
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
            IPAddress = $ip
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

$et=Get-Date
$duration = ($et - $st).TotalSeconds
Write-UTCLog "Finished in $($duration) Seconds" 
# generate new file name append "_result" in the same directory as the input file.
$csvresultfile=$csvfile.split('\')[-1].split('.')[0]+"_result.csv"
$resultfile="$env:temp\$csvresultfile"
if (Test-path $resultfile) {
    Write-UTCLog "File $($resultfile) exists. Remove it." "Yellow"
    Remove-Item $resultfile
}

$results | Sort-Object Latency_min | Export-Csv -Path $resultfile -NoTypeInformation    <# Action when all if and elseif conditions are false #>
Write-UTCLog "Export result to $($resultfile)" "Green"

#notepad++.exe $env:temp\azurespeed_armlocation_result.csv