# this script read the https://raw.githubusercontent.com/qliu95114/demystify/refs/heads/main/ps_azure/azurespeed_armlocation.csv
# and this file format is Cloud,Hostname
# script will test url and measure the latency

# Parameter help description
Param(
    [string]$csvfile="$PSScriptRoot\azurespeed_armlocation.csv",
    [int]$pingcount=10,
    [ValidateSet("icmp","tcp","ssl")][string]$protocol="icmp"
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
Write-UTCLog "Protocol : $($protocol.ToUpper())" 
Write-UTCLog "DomainName (total): $($hosts.count)" 

# Check curl.exe availability for TCP/SSL mode
if ($protocol -in "tcp","ssl") {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
        Write-UTCLog "curl.exe not found in PATH. Please install curl for TCP/SSL mode." "Red"
        exit 1
    }
}

$st=Get-Date
# Create a runspace pool for multi-threading
$maxThreads = [math]::Min([math]::Max(1, [int]([Environment]::ProcessorCount / 2)), $hosts.count)
Write-UTCLog "Threads (total): $maxThreads"
$runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads) # Min 1 thread, Max calculated threads
$runspacePool.Open()

# Create a list to hold the runspaces
$runspaces = [System.Collections.Generic.List[PSCustomObject]]::new()

# Loop through each hostname in the CSV
foreach ($h in $hosts) {
    $hostname = $h.Hostname
    $cloud = $h.Cloud

    # Create a new runspace for each host
    $runspace = [PowerShell]::Create()
    $runspace.RunspacePool = $runspacePool

    # Add script to the runspace
    [void]$runspace.AddScript({
        param($hostname,$cloud,$pingcount,$protocol)

        $latencies = [System.Collections.Generic.List[double]]::new()
        $ip = ""

        if ($protocol -in "tcp","ssl") {
            # TCP/SSL mode: use curl.exe to measure latency
            # TCP uses time_connect; SSL uses time_starttransfer (TTFB)
            $url = "https://$hostname"
            $metric = if ($protocol -eq "ssl") { "time_starttransfer" } else { "time_connect" }
            for ($i = 0; $i -lt $pingcount; $i++) {
                try {
                    $output = & curl.exe -s -k -o NUL --connect-timeout 1.0 -w "%{remote_ip}|%{$metric}" $url 2>$null
                    if ($output -and $output -match '^(.*)\|(.+)$') {
                        $remoteIp = $Matches[1]
                        $tcpTime = [double]$Matches[2]
                        if ($remoteIp -and $remoteIp -ne '0.0.0.0') { $ip = $remoteIp }
                        if ($tcpTime -gt 0) {
                            $latencies.Add([math]::Round($tcpTime * 1000, 2))  # seconds to ms
                        }
                    }
                } catch {
                    Write-Warning "curl failed for ${hostname}: $_"
                }
            }
        } else {
            # ICMP mode: use ping
            $ping = New-Object System.Net.NetworkInformation.Ping
            try {
                for ($i = 0; $i -lt $pingcount; $i++) {
                    try {
                        $reply = $ping.Send($hostname, 1000)
                        if ($reply.Status -eq "Success") {
                            $latencies.Add([double]$reply.RoundtripTime)
                        }
                    } catch {
                        Write-Warning "Ping failed for ${hostname}: $_"
                    }
                }
            } finally {
                $ping.Dispose()
            }
            # Get the IP address of the host, retry up to 10 times if failed
            for ($j = 0; $j -lt 10; $j++) {
                $dnsResult = Resolve-DnsName $hostname -ErrorAction SilentlyContinue
                if ($dnsResult) {
                    $ip = ($dnsResult | Where-Object { $_.IP4Address } | Select-Object -First 1).IP4Address
                }
                if ("" -ne $ip) { break }
                else { Start-Sleep -Milliseconds 50 }
            }
        }

        # Calculate the latency statistics for the host
        if ($latencies.Count -gt 0) {
            $stats = $latencies | Measure-Object -Average -Maximum -Minimum
            $avgLatency = [math]::Round($stats.Average, 2)
            $maxLatency = [math]::Round($stats.Maximum, 2)
            $minLatency = [math]::Round($stats.Minimum, 2)
            $sorted = $latencies | Sort-Object
            $p90Index = [math]::Ceiling(0.9 * $sorted.Count) - 1
            $p90Latency = [math]::Round($sorted[$p90Index], 2)
        } else {
            $avgLatency = "N/A"
            $maxLatency = "N/A"
            $minLatency = "N/A"
            $p90Latency = "N/A"
        }

        [PSCustomObject]@{
            Cloud = $cloud
            Hostname = $hostname
            IPAddress = $ip
            Latency_min = $minLatency
            Latency_max = $maxLatency
            Latency_avg = $avgLatency
            Latency_p90 = $p90Latency
        }
    }).AddArgument($hostname).AddArgument($cloud).AddArgument($pingcount).AddArgument($protocol)

    # Start the runspace and add it to the list
    $runspaces.Add([PSCustomObject]@{
        Runspace = $runspace.BeginInvoke()
        PowerShell = $runspace
    })
}

# Wait for all runspaces to complete and collect results
$results = [System.Collections.Generic.List[PSCustomObject]]::new()
$total = $runspaces.Count
$completed = 0
Write-Host "`r  [$protocol] Progress: 0 / $total hosts completed (0%)" -ForegroundColor Cyan -NoNewline
foreach ($rs in $runspaces) {
    $results.Add($rs.PowerShell.EndInvoke($rs.Runspace))
    $rs.PowerShell.Dispose()
    $completed++
    $pct = [math]::Round($completed / $total * 100)
    Write-Host "`r  [$protocol] Progress: $completed / $total hosts completed ($pct%)          " -ForegroundColor Cyan -NoNewline
}
Write-Host ""  # newline after progress

# Close the runspace pool
$runspacePool.Close()

# Display the results in a nicely formatted table
$results | Sort-Object { if ($_.Latency_min -eq "N/A") { [double]::MaxValue } else { [double]$_.Latency_min } } | Format-Table -AutoSize 

$et=Get-Date
$duration = ($et - $st).TotalSeconds
Write-UTCLog "Finished in $($duration) Seconds" 
# generate new file name append "_result" in the same directory as the input file.
$csvresultfile=[System.IO.Path]::GetFileNameWithoutExtension($csvfile)+"_result.csv"
$resultfile="$env:temp\$csvresultfile"
if (Test-path $resultfile) {
    Write-UTCLog "File $($resultfile) exists. Remove it." "Yellow"
    Remove-Item $resultfile
}

$results | Sort-Object { if ($_.Latency_min -eq "N/A") { [double]::MaxValue } else { [double]$_.Latency_min } } | Export-Csv -Path $resultfile -NoTypeInformation
Write-UTCLog "Export result to $($resultfile)" "Green"