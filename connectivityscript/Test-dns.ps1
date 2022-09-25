Param (
       [Parameter(Mandatory=$true)][string]$dnsname # input value

)

Function Write-Log ([string]$message,[string]$color)
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

while ($true)
{
    $commandcost =(Measure-Command {$a=(Resolve-DnsName $dnsname).ip4address}).Milliseconds
    Write-Log "resolving $dnsname result $a , time cost $commandcost" -color green
    start-sleep 5

}