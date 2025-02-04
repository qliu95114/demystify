# and this file format is Cloud,Hostname
# script will test url and measure the latency


Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

$csv = Import-Csv -Path azurespeed_armlocation.csv

foreach ($row in $csv) {
    $cloud = $row.Cloud
    $hostname = $row.Hostname

    try
    {
        # run ping to measure the latency
        $ping = New-Object System.Net.NetworkInformation.Ping
        #run 5 times and get the average latency
        $duration=0;$pingResult=0
        for ($i=1 ; $i -le 5; $i++) {
            $pingResult = $ping.Send($hostname).RoundtripTime
            $duration += $pingResult
            #Write-UTCLog "Latency for $cloud ($hostname): $($pingResult) ms" "Green"
        }
        $duration = $duration/5
        # calculate the latency
        $result = New-Object PSObject
        $result | Add-Member -MemberType NoteProperty -Name Cloud -Value $cloud
        $result | Add-Member -MemberType NoteProperty -Name Hostname -Value $hostname
        $result | Add-Member -MemberType NoteProperty -Name Latency -Value $duration
        $result | Export-Csv -Path $env:temp\azurespeed_armlocation_result.csv -NoTypeInformation -Append

        Write-UTCLog "Latency for $cloud ($hostname): $($duration) ms" "Green"
        #$result += $result
    }
    catch
    {
        Write-UTCLog "Ping $hostname Error : $($_.Exception.Message) : " "Red"
    }
}
$result | Export-Csv -Path $env:temp\azurespeed_armlocation_result_single.csv -NoTypeInformation

notepad++ $env:temp\azurespeed_armlocation_result_single.csv






