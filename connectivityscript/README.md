# All kinds of connectivity scripts

1. Test-dns.ps1
1. Test-Https.ps1
1. Test-ICMP.ps1
1. Test-IpInRange.ps1
1. Test-PSPing.ps1
1. Test_tcpping.sh
1. UdpPing.ps1
1. UdpSend.ps1
1. UdpSend_batch.ps1


# One Line Script (Windows & Linux)

## Windows - Powershell (HTTPS)
```
# output curl.exe result with UTC timestamp, Console & LogFile : $env:temp\$env:computername_curl.log, output / result are splitted. 
$url="www.bing.com";$interval=3;while ($true) {curl.exe -s -w "dns_resolution: %{time_namelookup}, tcp_established: %{time_connect}, ssl_handshake_done: %{time_appconnect}, TTFB: %{time_starttransfer}, HTTPSTATUS: %{http_code}" https://$($url) -o "$($env:temp)\$($env:computername)_curl_result.html"|foreach {"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$url,$_;"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$url,$_|out-file "$($env:temp)\$($env:computername)_curl.log" -append -encoding utf8; start-sleep $interval}}

# output curl.exe result with UTC timestamp, Console & LogFile : $env:temp\$env:computername_curl.log, output / result are together same file
$url="www.bing.com";$interval=3;while ($true) {curl.exe -w "dns_resolution: %{time_namelookup}, tcp_established: %{time_connect}, ssl_handshake_done: %{time_appconnect}, TTFB: %{time_starttransfer}, HTTPSTATUS: %{http_code}" https://$($url) |foreach {"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$url,$_;"{0},{1},{2}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"),$url,$_|out-file "$($env:temp)\$($env:computername)_curl.log" -append -encoding utf8; start-sleep $interval}}

```
### sample output
```
2023-01-29 04:37:46,www.bing.com,dns_resolution: 0.027826, tcp_established: 0.104387, ssl_handshake_done: 0.268914, TTFB: 0.415539, HTTPSTATUS: 200
2023-01-29 04:37:49,www.bing.com,dns_resolution: 0.010106, tcp_established: 0.080188, ssl_handshake_done: 0.247045, TTFB: 0.395230, HTTPSTATUS: 200
2023-01-29 04:37:53,www.bing.com,dns_resolution: 0.009926, tcp_established: 0.090002, ssl_handshake_done: 0.255321, TTFB: 0.403124, HTTPSTATUS: 200
2023-01-29 04:37:56,www.bing.com,dns_resolution: 0.009757, tcp_established: 0.079645, ssl_handshake_done: 0.242734, TTFB: 0.390715, HTTPSTATUS: 200

```

## Windows - Command Prompt (TCP)
```
# output psping result to LogFile : %temp%\%computername%_psping.log)
psping.exe -t sha-qliu-01 |find /v ""|cmd /q /v:on /c "for /l %a in (0) do (set "data="&set /p "data="&if defined data echo(!date! !time! !data!)">%temp%\%computername%_psping.log

# add timezone details at LogFile : %temp%\%computername%_psping.log 
systeminfo | findstr /L "Zone:"  > %temp%\%computername%_psping.log
psping.exe -t www.bing.com:443 |cmd /q /v /c "(pause&pause)>nul & for /l %a in () do (set /p "data=" && echo(!date! !time! !data!)&ping -n 2 www.bing.com >nul)" >> %temp%\%computername%_psping.txt
```

## Windows - Powershell (TCP)
```
# output with UTC timestamp - Console & LogFile : %temp%\%computername%_psping.log (Encoding: utf8) (**Recommended**)
psping.exe -t www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_psping.log" -append -encoding utf8}

# output with local timestamp - Console 
psping.exe -t www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}

# output with UTC timestamp - LogFile : %temp%\%computername%_psping.log
psping.exe -t www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}|Out-File "$($env:temp)\$($env:computername)_psping.log" -append  -encoding utf8

# output with UTC timestamp - Console & LogFile %temp%\%computername%_psping.log (Encoding: utf8) , [-i interval] [-w count] -4 or -6
psping.exe -4 -t -i 3 -w 10 www.bing.com:80 /Accepteula | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_psping.log" -append -encoding utf8}
```

## Windows - Powershell (ICMP)
```
# output with UTC timestamp - Console & LogFile : %temp%\%computername%_ping.log
ping.exe -t 25.7.24.10 | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_ping.log"  -append -encoding utf8}

# output with UTC timestamp - LogFile : %temp%\%computername%_ping.log
ping.exe -t 25.7.24.10 | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "$($env:temp)\$($env:computername)_ping.log" -append -encoding utf8}

# output with UTC Timestamp - Console  
ping.exe -t 25.7.24.10 | Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}
```

## Linux - Scripting (TCP)

### paping (paping has latency details) 
```
#install paping
wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/paping/paping_1.5.5_x86-64_linux.tar.gz
tar zxvf paping_1.5.5_x86-64_linux.tar.gz
sudo su  #must be in sudo mode. 

# output with UTC timestamp - Console & File "$(hostname -s)_paping.log"  (tested on ubuntu) 
./paping www.bing.com -p 443| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong";done 2>&1 | tee "$(hostname -s)_paping.log"

# paping [-c count]
./paping -c 10 www.bing.com -p 443 

```

### netcat (nc)
```
# output with UTC timestamp - Console & File "$(hostname -s)_nc.log" (tested on ubuntu) 
while true; do echo "`date -u +'%F %H:%M:%S'` - `nc -vvzw 2 www.bing.com 443 2>&1`";sleep 1; done 2>&1 | tee "$(hostname -s)_nc.log"
```
## Linux - Script (ICMP)

```
# output with UTC timestamp - Console & File "$(hostname -s)_ping.log" (tested on ubuntu)  
while true; do ping 192.168.3.5 -w 3 -c 1 -i 3| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong"; done ;sleep 1; done 2>&1 | tee "$(hostname -s)_ping.log"


ping 192.168.3.5| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong"; done 2>&1 | tee "$(hostname -s)_ping.log"
ping 192.168.3.5| while read pong; do echo "$(date -u +'%F %H:%M:%S') - $pong"; done 
```