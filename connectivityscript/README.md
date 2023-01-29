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

## Windows - Command Prompt 
```
# output psping result to %temp%\%computername%_psping.txt 
psping -t sha-qliu-01 |find /v ""|cmd /q /v:on /c "for /l %a in (0) do (set "data="&set /p "data="&if defined data echo(!date! !time! !data!)">%temp%\%computername%_psping.txt

# add timezone details at begining %temp%\%computername%_psping.txt 
systeminfo | findstr /L "Zone:"  > %temp%\%computername%_psping.txt
psping -t www.bing.com:443 |cmd /q /v /c "(pause&pause)>nul & for /l %a in () do (set /p "data=" && echo(!date! !time! !data!)&ping -n 2 www.bing.com >nul)" >> %temp%\%computername%_psping.txt
```

## Windows - Powershell
```
# output with local time - console only
.\psping -t www.bing.com:80|Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}

# output with UTC timestamp - console only 
.\psping.exe -t www.bing.com:80|Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}

# output with UTC timestamp - file %temp%\%computername%_psping.log
.\psping.exe -t www.bing.com:80|Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_}|Out-File $env:temp"\"$env:computername"_psping.log" -append

# output with UTC timestamp - console & file %temp%\%computername%_psping.log
.\psping.exe -t www.bing.com:80|Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File $env:temp"\"$env:computername"_psping.log" -append}

# output with UTC /acceteula - console & file %temp%\%computername%_psping.log (Encoding: utf8)  
.\psping.exe -t -i 3 -w 60 www.bing.com:80 /Accepteula|Foreach{"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_;"{0} - {1}" -f (Get-Date).ToUniversalTime(),$_|Out-File "C:\log\$env:computername-psping_www.bing.com_80.log" -append -Encoding utf8}
```

## Linux - Scripting
### paping (paping has latency details)
```
#install paping
wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/paping/paping_1.5.5_x86-64_linux.tar.gz
tar zxvf paping_1.5.5_x86-64_linux.tar.gz
sudo su  #must be in sudo mode. 
./paping -p 3389 -c 10 192.168.3.5 | while read pong; do echo "$(date): $pong";done >"tcpping_$HOSTNAME_192.168.3.5.log"
./paping -p 3389 -c 10 192.168.3.5 | while read pong; do echo "$(date -u +'%F %H:%M:%S'): $pong";done >"tcpping_$HOSTNAME_192.168.3.5.log"
./paping -p 3389 -c 10 192.168.3.5 | while read pong; do echo "$(date -u +'%F %H:%M:%S'): $pong";done
./paping -p 3389 -c 10 192.168.3.5 | while read pong; do echo "$(date -u +'%F %H:%M:%S'): $pong";done >"tcpping_$HOSTNAME_192.168.3.5.log"
```

### netcat (nc)
```
while true ; do echo -n "$(date -u +'%F %H:%M:%S'):" ; nc -zv -w 1 10.224.0.4 443 ;sleep 1 ;done
while `sleep 1` ; do time echo "`date -u +'%F %H:%M:%S'` - `nc -vvzw 2 192.168.10.2 3389 2>&1`" ; done >"tcpping_$HOSTNAME_192.168.3.5.log"
```
