# this script handle all files in a given directory
# get all stats*.log

# process all files in a directory
# Parameter help description
Param(
    [string]$folder = $(Get-Location)
)
Function Write-UTCLog ([string]$message,[string]$color="green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
    	#Write-Output $logstamp | Out-File $ReportFile -Encoding UTF8 -append
}

Write-UTCLog "Processing all stats*.log files in $folder" "green"

$st=Get-Date

$files = Get-ChildItem -Path $folder -Filter "stats*.log" -File

# if no files found, exit
if ($files.Count -eq 0) {
    Write-UTCLog "No stats*.log files found in $folder" "red"
    exit
}
# Create a runspace pool for multi-threading
$maxThreads = [math]::Min((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors, $files.count)
Write-UTCLog "Threads (total): $maxThreads"
$runspacePool = [RunspaceFactory]::CreateRunspacePool(1, $maxThreads) # Min 1 thread, Max calculated threads
$runspacePool.Open()

# Create a list to hold the runspaces
$runspaces = @()

# get all stats*.log files in the current directory

$i=0
# loop through each file
foreach ($file in $files) {
    # read the file line by line and output a file with filename_timeadded.log

    # Create a new runspace for each host
    $runspace = [PowerShell]::Create()
    $runspace.RunspacePool = $runspacePool

    # Add script to the runspace
    [void]$runspace.AddScript({
        param($file,$folder)
        
        $lines = Get-Content -Path $file.FullName
        $outputFileName = "$($folder)\$($file.BaseName)_ttadded.log"        

        #Write-UTCLog "Processing file $($file.FullName)" "green"
        # loop through each line, 
        # if line starts with ^# (\d{8}-\d{6})$, get timestamp 
        # if line is empty skip it
        # if line is part of qdisc, merge into online, exit gate is "NIC statistics:' 
        # everything else add timestamp.increment number and write it to the output file

        $qdisc = false
        $qdiscLine =
        foreach ($line in $lines) {
            switch -regex ($line) {
                '^# (\d{8}-\d{6})' {
                    # get the timestamp from the line
                    $a = $matches[1]
                    $timestamp = $a.Substring(0,4) + '-' + $a.Substring(4,2) + '-' + $a.Substring(6,2) + ' ' + $a.Substring(9,2) + ':' + $a.Substring(11,2) + ':' + $a.Substring(13,2)
                    $index = 0  # reset index to 0
                    break
                }
                '^$' {
                    # skip empty lines
                    continue
                }
                '^qdisc '
                {
                    # if $qdiscline is found, need flush the previous $qdisc line if exists, then set the $qdisc to true
                    if ([string]::IsNullOrEmpty($qdiscLine) -eq $false) {
                        $qdiscLine | Out-File -FilePath $outputFileName -Append -Encoding UTF8
                    }
                    $qdisc = $true
                    $indexstr = "{0:D6}" -f $index
                    $qdiscLine = $timestamp+"."+$indexstr+" $line"
                }
                '^NIC statistics:' # exit qdisc loop
                {
                    # if $qdiscline is found, need flush the previous $qdisc line if exists, then set the $qdisc to false
                    if ([string]::IsNullOrEmpty($qdiscLine) -eq $false) {
                        $qdiscLine | Out-File -FilePath $outputFileName -Append -Encoding UTF8
                    }
                    # clean up the $qdiscLine 
                    $qdisc = $false
                    $qdiscLine = ""
                    # write the line to the output file
                    $index++                    
                    $indexstr = "{0:D6}" -f $index
                    $newLine = $timestamp+"."+$indexstr+" $line"
                    $newLine | Out-File -FilePath $outputFileName -Append -Encoding UTF8                    
                }
                default {
                    $index++
                    # make index to be 6 digits fill with 0
                    if ($qdisc -eq $true) {
                        # if qdisc is true, add the content to the $qdiscLine without flush to $outputFileName
                        $qdiscLine += "$line"
                    } else {
                        $indexstr = "{0:D6}" -f $index
                        $newLine = $timestamp+"."+$indexstr+" $line"
                        $newLine | Out-File -FilePath $outputFileName -Append -Encoding UTF8
                    }
                }
            }
        }
    }).AddArgument($file).AddArgument($folder)

    # Start the runspace and add it to the list
    $runspaces += [PSCustomObject]@{
        Runspace = $runspace.BeginInvoke()
        PowerShell = $runspace
    }
    $i++
    Write-UTCLog "$($i)/$($files.count) : Processing file $($file.FullName)" "green"
}

Write-UTCLog "Waiting for all runspaces to complete..." "green"
# Wait for all runspaces to complete and collect results
$results = @()
foreach ($rs in $runspaces) {
    $results += $rs.PowerShell.EndInvoke($rs.Runspace)
}

# Close the runspace pool
$runspacePool.Close()






