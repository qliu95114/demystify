# All kinds of connectivity scripts

| win | linux | python |
|-|-|-|
|[Test-dns.ps1](win/Test-dns.ps1) | [Test_tcpping.sh](linux/Test_tcpping.sh)| [tcping_ai.py](py/tcping_ai.py)|
|[Test-curl.ps1](win/Test-Https.ps1)|[Test_dns.sh](linux/test_dns.sh)||
|[Test-Https.ps1](win/Test-Https.ps1)|[Test_dnsfile.sh](linux/test_dnsfile.sh)||
|[Test-ICMP.ps1](win/Test-ICMP.ps1)|[Test_ping.sh](linux/test_ping.sh)||
|[Test-IpInRange.ps1](win/Test-IpInRange.ps1)|||
|[Test-PSPing.ps1](win/Test-PSPing.ps1)|||
|[Test-PSping_batch.ps1](win/Test-PsPing_batch.ps1)|||
|[UdpPing.ps1](win/UdpPing.ps1)|||
|[UdpSend.ps1](win/UdpSend.ps1)|||
|[UdpSend_batch.ps1](win/UdpSend_batch.ps1)|||


# One Line Script (Windows & Linux)

## Windows - Powershell (HTTPS/HTTP - cURL.exe)

Output curl.exe result with UTC timestamp
Console & LogFile : $env:temp\$env:computername_curl.log, 
Output / result are splitted. 
```
$url="https://www.bing.com";$interval=4;$timeout="1.0";$hostname=$url.split('/')[2].split(':')[0];$p=$url.split(':')[0];while ($true) {curl.exe --connect-timeout $($timeout) -s -w "remote_ip:%{remote_ip},dns_resolution:%{time_namelookup},tcp_established:%{time_connect},ssl_handshake_done:%{time_appconnect},TTFB:%{time_starttransfer},httpstatus:%{http_code},size_download:%{size_download}" $url -o "$($env:temp)\$($env:computername)_curl_$($p)_$($hostname)_result.html"|foreach {"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$hostname,$_;"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$hostname,$_|out-file "$($env:temp)\$($env:computername)_curl_$($p)_$($hostname).log" -append -encoding utf8; start-sleep $interval}}
```
Output curl.exe result with UTC timestamp, 
Console & LogFile : $env:temp\$env:computername_curl.log, 
output / result are together in one file
```
$url="https://www.bing.com";$interval=4;$timeout="1.0";$hostname=$url.split('/')[2].split(':')[0];$p=$url.split(':')[0];while ($true) {curl.exe --connect-timeout $($timeout) -w "dns_resolution: %{time_namelookup}, tcp_established: %{time_connect}, ssl_handshake_done: %{time_appconnect}, TTFB: %{time_starttransfer}, HTTPSTATUS: %{http_code}" $url |foreach {"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$hostname,$_;"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$hostname,$_|out-file "$($env:temp)\$($env:computername)_curl_$($p)_$($hostname).log" -append -encoding utf8; start-sleep $interval}}

```

Sample output
```
2023-04-01 03:42:31,www.bing.com,remote_ip:204.79.197.200,dns_resolution:0.019208,tcp_established:0.090411,ssl_handshake_done:0.255966,TTFB:0.432676,httpstatus:200,size_download:89177
2023-04-01 03:42:37,www.bing.com,remote_ip:204.79.197.200,dns_resolution:0.007000,tcp_established:0.090975,ssl_handshake_done:0.257738,TTFB:0.447636,httpstatus:200,size_download:89179
2023-04-01 03:42:42,www.bing.com,remote_ip:204.79.197.200,dns_resolution:0.011646,tcp_established:0.082188,ssl_handshake_done:0.253898,TTFB:0.428031,httpstatus:200,size_download:89413

```

## Windows - Powershell (HTTP/HTTPS - Invoke-WebRequest(IWR))
|Powershell Command-Prompt|Powershell Core Command-Prompt|
|-|-|
|Script will use one TCP stream, same source port, continoue traffic.|Script will create new tcp stream for every IWR request|
```
$url="https://www.bing.com";$interval=1;$timeout=5;while ($true) {try {$iwr=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeout;"{0},{1},{2},{3},{4}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$($url),$iwr.StatusCode,$iwr.StatusDescription,$iwr.RawContentLength } catch {    $iwr = $_.Exception.Message; "{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$url,$iwr }; sleep $interval}
```
Sample output
```
2023-04-01 04:09:14,https://ipinfo.io,The operation has timed out.
2023-04-01 04:09:20,https://ipinfo.io,The operation has timed out. 
2023-04-01 04:12:21,https://portal.azure.cn/abc,200,OK,2880
2023-04-01 04:12:22,https://portal.azure.cn/abc,200,OK,2880
2023-04-01 04:13:06,https://management.azure.cn,The remote name could not be resolved: 'management.azure.cn'
2023-04-01 04:13:07,https://management.azure.cn,The remote name could not be resolved: 'management.azure.cn'
2023-04-01 04:13:18,https://management.chinacloudapi.cn,The remote server returned an error: (400) Bad Request.
2023-04-01 04:13:19,https://management.chinacloudapi.cn,The remote server returned an error: (400) Bad Request.
```
## Windows - Command Prompt (TCP - PSPING.EXE)

Result to LogFile : %temp%\%computername%_psping.log
```
psping.exe -t sha-qliu-01 |find /v ""|cmd /q /v:on /c "for /l %a in (0) do (set "data="&set /p "data="&if defined data echo(!date! !time! !data!)">%temp%\%computername%_psping.log
```
Result to LogFile : %temp%\%computername%_psping.log and add TimeZone Information
```
systeminfo | findstr /L "Zone:"  > %temp%\%computername%_psping.log
psping.exe -t www.bing.com:443 |cmd /q /v /c "(pause&pause)>nul & for /l %a in () do (set /p "data=" && echo(!date! !time! !data!)&ping -n 2 www.bing.com >nul)" >> %temp%\%computername%_psping.txt
```

## Windows - Powershell (TCP - Test-Connection)
```
Test-Connection -Count 9999 www.bing.com | Format-Table @{Name='TimeStamp';Expression={(get-date).ToUniversalTime().ToString("yyyy-MM-ddT HH:mm:ss")}},Address,ProtocolAddress,ResponseTime
```

## Windows - Powershell (TCP - PSPING.EXE)

**Recommended** Output psping.exe result with UTC timestamp
Console & LogFile : %temp%\%computername%_psping.log (Encoding: utf8) 
```
psping.exe -t www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_psping.log" -append -encoding utf8}
```

Output psping.exe result with UTC timestamp - Console 
```
psping.exe -t www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}
```
Output psping.exe result with UTC timestamp - LogFile : %temp%\%computername%_psping.log
```
psping.exe -t www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}|Out-File "$($env:temp)\$($env:computername)_psping.log" -append  -encoding utf8
```
Output psping.exe result with UTC timestamp - Console & LogFile %temp%\%computername%_psping.log (Encoding: utf8) , [-i interval] [-w count] -4 or -6
```
psping.exe -4 -t -i 3 -w 10 www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_psping.log" -append -encoding utf8}
```

## Windows - Powershell (ICMP - PING.EXE)

Output ping.exe result with UTC timestamp 
Console & LogFile : %temp%\%computername%_ping.log
```
ping.exe -t 25.7.24.10 | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_ping.log"  -append -encoding utf8}
```
LogFile : %temp%\%computername%_ping.log
```
ping.exe -t 25.7.24.10 | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_ping.log" -append -encoding utf8}
```
Console  
```
ping.exe -t 25.7.24.10 | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}
```

## Linux - Script (TCP - paping)

Install paping
```
wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/paping/paping_1.5.5_x86-64_linux.tar.gz
tar zxvf paping_1.5.5_x86-64_linux.tar.gz
sudo su  #must be in sudo mode. 
```
Output paping result with UTC timestamp
Console & LogFile : "$(hostname -s)_paping.log"
```
target="www.bing.com";port="443";./paping $target -p $port| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong";done 2>&1 | tee -a "$(hostname -s)_paping_${target}_${port}.log"
```
paping command
```
paping [-c count]
./paping -c 10 www.bing.com -p 443 

```

## Linux - Script (TCP - netcat(nc))

Output paping result with UTC timestamp
Console & LogFile : "$(hostname -s)_nc.log"
```
target="www.bing.com";port=443;while true; do echo "`date -u +'%F %H:%M:%S'` - `nc -vvzw 2 $target $port 2>&1`";sleep 1; done 2>&1 | tee -a "$(hostname -s)_nc_${target}_${port}.log"
```

## Linux - Script (ICMP - ping)

Output ping result with UTC timestamp
Console & LogFile : "$(hostname -s)_ping.log"
```
ipaddr="192.168.3.11";ping -O $ipaddr -W 1 -i 1| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong"; done 2>&1 | tee -a "$(hostname -s)_ping_${ipaddr}.log"
ipaddr="192.168.3.11";ping -O $ipaddr -W 1 -i 1| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong"; done 
```
```
ipaddr="192.168.3.11";while true; do ping -O $ipaddr -W 1 -c 1| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong"; done ;sleep 1; done 2>&1 | tee -a "$(hostname -s)_ping_${ipaddr}.log"
```

## Linux - Script (HTTPS/HTTP - curl)

Output Curl output with UTC timstamp
Console & LogFile : "$(hostname -s)_curl.log"
```
url="https://www.google.com";timeout="1.0";interval=4;hh=$(echo $url|cut -d'/' -f3);while true; do curl -o /dev/null --connect-timeout $timeout -s -w "${hh},remote_ip:%{remote_ip},dns_resolution:%{time_namelookup},tcp_established:%{time_connect},ssl_handshake_done:%{time_appconnect},TTFB:%{time_starttransfer},httpstatus:%{http_code},size_download:%{size_download}\n" $url | while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong"; done; sleep $interval; done 2>&1 | tee -a "$(hostname -s)_curl_${hh}.log"
```


