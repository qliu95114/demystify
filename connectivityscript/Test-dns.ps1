# Script to test DNS
# > specify DNS NAME
# > specify dnsnamelist.txt
# > specify spedific dns server by ip address
# > support Applicaiton Insight.


Param (
       [string]$dnsname, # input value
       [string]$dnslistfile,
       [string]$dnsserver,
       [int]$timeout=5,
       [int]$count=10
)

Function Write-Log ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

Function invoke_nslookup([string]$dns,[string]$dnsserver)
{
    $cmd="nslookup -timeout=$($timeout) -retry=1 -type=A $($dns). $($dnsserver)"
    #$cmd
    $duration=(measure-command {$result=iex $cmd }).TotalSeconds
    for ($i=2;$i -le $result.count;$i++)  {$dnsresult+=$result[$i]+"_"} 
    $dnsresult=$dnsresult.trim("_")
    Write-Log "$($duration),$($dnsresult)" "green"
}

#main
Write-Log " Timeout : $($timeout)" 
Write-Log " Count : $($count)" 
if ([string]::IsNullOrEmpty($dnsname) -and [string]::IsNullOrEmpty($dnslistfile)) 
{
    $dnsname="www.bing.com"
    Write-Log "-dnsname and -dnslistfile both empty, use default 'www.bing.com' to test"
    for ($i=1;$i -le $count;$i++)  { invoke_nslookup -dns $dnsname -dnsserver $dnsserver }
}
else {
    if ([string]::IsNullOrEmpty($dnslistfile)) 
    {
        Write-Log " Dnsname : $($dnsname)"
        for ($i=1;$i -le $count;$i++)  { invoke_nslookup -dns $dnsname -dnsserver $dnsserver }
    }
    else {
        Write-Log " DnsListFile : $($dnslistfile)"
    }
}

<#
while ($true)
{
    $commandcost =(Measure-Command {$a=(Resolve-DnsName $dnsname).ip4address}).Milliseconds
    Write-Log "resolving $dnsname result $a , time cost $commandcost" -color green
    start-sleep 5

}#>