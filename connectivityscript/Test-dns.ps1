<#
.SYNOPSIS
DNS Test script and output to local log file
> provide one DNS name 
> specify TEXT file contains a list of DNS name
> specify repeat count

.DESCRIPTION
DNS Test script and output to local log file
> provide one DNS name 
> specify TEXT file contains a list of DNS name
> specify repeat count

.PARAMETER dnsname
The name of the file to be converted, please include full path of the file , wildchar is not supported. 

.PARAMETER dnslistfile
Starting Seconds we will cut from the beginning, Default 0

.PARAMETER dnsserver
Target DNS server, for example 8.8.8.8 or 168.63.129.16 

.PARAMETER logfile
Logfile 

.PARAMETER timeout
DNS Query timeout settings, default 5

.PARAMETER count 
Repeat , default 10

.PARAMETER deplay
Milliseconds, delay between each batch , default 1000

.EXAMPLE
.\Test-dns.ps1 -delay 0 -dnsname www.bing.com

.EXAMPLE
.\Test-dns.ps1 -delay 0 -dnslistfile D:\temp\dnsname.txt -timeout 1

.EXAMPLE
.\Test-dns.ps1 -delay 0 -dnslistfile D:\temp\dnsname.txt -timeout 1 -dnsserver 1.1.1.1 -logfile d:\temp\a.log

#>

Param (
       [string]$dnsname, # input value
       [string]$dnslistfile,
       [string]$dnsserver,
       [int]$timeout=5,
       [int]$count=10,
       [int]$delay=1000,
       [string]$logfile 
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
    $cmd
    $duration=(measure-command {$result=iex $cmd }).TotalSeconds
    for ($i=2;$i -le $result.count;$i++)  {$dnsresult+=$result[$i]+"|"} 
    $dnsresult=$dnsresult.trim("|")
    # HACKING if there is no return assume we get DNS response of NXDOAIMN
    if ([string]::IsNullOrEmpty($dnsresult)) { $dnsresult="can't find $($dns).: Non-existent domain"}
    Write-Log "$($duration),$($dns),$($dnsresult)" "green"
    $Message="$(((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")),$($duration),$($dns),$($dnsresult)"
    $Message | Out-File $logfile -Append -Encoding utf8
}

#main
Write-Log " Timeout   : $($timeout)" 
Write-Log " Count     : $($count)" 
Write-Log " Delay(ms) : $($delay)"

If ([string]::IsNullOrEmpty($logfile)) 
{
    # use default path $env:temp , $env:computename, TEST-DNS, utc timestamp 
    $logfile= Join-Path  $($env:temp) $($env:COMPUTERNAME+"_Test-DNS_"+((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmss")+".log")
}

Write-Log " LogFile   : $($logfile)"
$header="TIMESTAMP,Duration,DNSNAME,RESULT"
$header|Out-File $logfile -Encoding utf8

if ([string]::IsNullOrEmpty($dnsname) -and [string]::IsNullOrEmpty($dnslistfile)) 
{
    $dnsname="www.bing.com"
    Write-Log "-dnsname and -dnslistfile both empty, use default 'www.bing.com' to test"
    for ($i=1;$i -le $count;$i++)  { invoke_nslookup -dns $dnsname -dnsserver $dnsserver; start-sleep -Milliseconds $delay }
}
else {
    if ([string]::IsNullOrEmpty($dnslistfile)) 
    {
        Write-Log " Dnsname   : $($dnsname)"
        for ($i=1;$i -le $count;$i++)  { invoke_nslookup -dns $dnsname -dnsserver $dnsserver }
    }
    else {
        Write-Log " DnsList   : $($dnslistfile)"
        if (Test-Path $dnslistfile)
        {
            $dnslist=get-content $dnslistfile
            Write-Log " DnsRecord : $($dnslist.count)"
            for ($i=1;$i -le $count;$i++) 
            { 
                foreach ($dns in $dnslist)
                {
                    #Write-Log " DNS : $($dns)"
                    invoke_nslookup -dns $dns -dnsserver $dnsserver; start-sleep -Milliseconds $delay
                }
            }
        }
        else {
            Write-Log "$($dnslistfile) does not exsit, please double-check!"
        }
    }
}

