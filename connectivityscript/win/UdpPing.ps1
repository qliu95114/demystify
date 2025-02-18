#############################################################################
#Author: Qing Liu,

#Usage: Send Payload to UDP port and read return data , timeout setting is 1 s
#Output: 

<#
PS D:\source_git\Script> .\UdpPing.ps1 -port 9030 -n 2
[2021-01-08 15:05:24],Session Started
[2021-01-08 15:05:24],Server : 20.37.85.37     Port : 9030   N(repeat) : 2  Payloadsize : 10
[2021-01-08 15:05:24],Send Message    : MYKWAXCSAY
[2021-01-08 15:05:24],Receive Message : MYKWAXCSAY , Latency: 0.1369 s
[2021-01-08 15:05:25],Send Message    : MYKWAXCSAY
[2021-01-08 15:05:26],Receive Message : MYKWAXCSAY , Latency: 0.1373 s
PS D:\source_git\Script> .\UdpPing.ps1 -port 8030 -n 2
[2021-01-08 15:05:34],Session Started
[2021-01-08 15:05:34],Server : 20.37.85.37     Port : 8030   N(repeat) : 2  Payloadsize : 10
[2021-01-08 15:05:34],Send Message    : LJDDJLYHCO
[2021-01-08 15:05:35],Receive Message : Error, timeout 1 second
[2021-01-08 15:05:36],Send Message    : LJDDJLYHCO
[2021-01-08 15:05:37],Receive Message : Error, timeout 1 second
#>

#Dependencies: start udp listen server 
# sample command 
# # socat -v udp4-recvfrom:9030,reuseaddr,fork exec:"sh -c 'cat'"
# # nohup socat -v udp4-recvfrom:3479,reuseaddr,fork exec:"sh -c 'cat'" > /tmp/udpserver3479.log 2>&1 &
# # nohup socat -v udp4-recvfrom:3480,reuseaddr,fork exec:"sh -c 'cat'" > /tmp/udpserver3480.log 2>&1 &
# # nohup socat -v udp4-recvfrom:3481,reuseaddr,fork exec:"sh -c 'cat'" > /tmp/udpserver3481.log 2>&1 &
# or use python sample https://github.com/wangyu-/UDPping/blob/master/udpping.py
##################################################################################

Param (
    [string]$Server="127.0.0.1",
    [int]$port=9030,
    [int]$timeout=1000, #timeout in ms
    [int]$wait=1000, #wait time in ms
    [ValidateRange(0,99999)][int]$n=10, #0 forever
    [ValidateRange(5,10000)][Int]$payloadsize=10,  #put a hack value here, if the payload size is 1314, the will be ms-team fake STUN protocol 
    #$hexstring="00 03 00 30 21 12 a4 42 67 64 29 c0 9d 9a ba b5 68 5e b8 b6 00 0f 00 04 72 c6 4b c6 80 37 00 04 00 00 00 02 80 08 00 04 00 00 00 06 80 06 00 04 00 00 00 01 00 10 00 04 00 00 2e e0 80 55 00 04 00 01 00 02"
    [string]$logpath=$env:temp,# log file path and log filename will be udping_$server_$port_yyyymmdd_hhmmss.log
    [string]$aikey,
    [switch]$debug
)

#Send-UdpDatagram -EndPoint $Endpoint -Port $port -Message "test.mymetric:0|c"      
Function Write-UTCLog ([string]$message,[string]$color)
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
       Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

# Powershell Function Send-AIEvent , 2024-04-12
Function Send-AIEvent{
      param (
                  [Guid]$piKey,
                  [String]$pEventName,
                  [Hashtable]$pCustomProperties,
                  [string]$logpath=$env:TEMP
      )
          $appInsightsEndpoint = "https://dc.services.visualstudio.com/v2/track"        
          
          if ([string]::IsNullOrEmpty($env:USERNAME)) {$uname=($env:USERPROFILE).split('\')[2]} else {$uname=$env:USERNAME}
          if ([string]::IsNullOrEmpty($env:USERDOMAIN)) {$domainname=$env:USERDOMAIN_ROAMINGPROFILE} else {$domainname=$env:USERDOMAIN}
              
          $body = (@{
                  name = "Microsoft.ApplicationInsights.$iKey.Event"
                  time = [DateTime]::UtcNow.ToString("o")
                  iKey = $piKey
                  tags = @{
                      "ai.user.id" = $uname
                      "ai.user.authUserId" = "$($domainname)\$($uname)"
                      "ai.cloud.roleInstance" = $env:COMPUTERNAME
                      "ai.device.osVersion" = [System.Environment]::OSVersion.VersionString
                      "ai.device.model"= (Get-CimInstance CIM_ComputerSystem).Model
  
            }
              "data" = @{
                      baseType = "EventData"
                      baseData = @{
                          ver = "2"
                          name = $pEventName
                          properties = ($pCustomProperties | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
                      }
                  }
              }) | ConvertTo-Json -Depth 10 -Compress
      
          $temp = $ProgressPreference
          $ProgressPreference = "SilentlyContinue"
  
          $attempt=1
          do {
              try {
                  Invoke-WebRequest -Method POST -Uri $appInsightsEndpoint -Headers @{"Content-Type"="application/x-json-stream"} -Body $body -TimeoutSec 3 -UseBasicParsing| Out-Null 
                  return    
              }
              catch {
                  #Write-UTCLog "Send-AIEvent Failure: $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message)" -color "red"
                  # determine if exception code < 400 and >= 500, or code is 429, we will retry
                  $PreciseTimeStamp=((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")                
                  if (($_.Exception.Response.StatusCode.value__ -lt 400 -or $_.Exception.Response.StatusCode.value__ -ge 500) -or ($_.Exception.Response.StatusCode.value__ -eq 429))
                  {
                      #retry total 3 times, if failed, add message to aimessage.log and return $null
                      if ($attempt -ge 4)
                      {
                          Write-Output "retry 3 failure..." 
                          $sendaimessage =$PreciseTimeStamp+", Max retry attemps 3 reached, message lost"
                          $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                          return $null
                      }
                      Write-Output "Send-AIEvent Attempt($($attempt)): send aievent failure, retry" 
                      $sendaimessage =$PreciseTimeStamp+", Attempt($($attempt)) , $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message), retry..."
                      $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                      Start-Sleep -Seconds 1
                  }
                  else {
                      # unretrable error add message to aimessage.log and return $null
                      Write-UTCLog "Send-AIEvent unretrable error, message lost, $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message)" -color "red"
                      $sendaimessage=$PreciseTimeStamp+"Send-AIEvent unretrable error, message lost, $($_.Exception.Response.StatusCode.value__), $($_.Exception.Message)"
                      $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                      return $null
                  }
              }
              $attempt++
          } until ($success)
          $ProgressPreference = $temp
  }
  
  
function Send-UdpDatagram
{
      Param ([string] $EndPoint, 
      [int] $Port, 
      [string] $Message,
      [int] $timeout=1000,
      [string] $logfile)

      $IP = [System.Net.Dns]::GetHostAddresses($EndPoint) 
      $Address = [System.Net.IPAddress]::Parse($IP) 
      $EndPoints = New-Object System.Net.IPEndPoint($Address, $Port) 
      $Socket = New-Object System.Net.Sockets.UDPClient 
      $Socket.Client.ReceiveTimeout = $timeout

      if ($Message -eq "STUN") {
            # STUN Refresh request 
            #$EncodedText = "00 03 00 30 21 12 a4 42 67 64 29 c0 9d 9a ba b5 68 5e b8 b6 00 0f 00 04 72 c6 4b c6 80 37 00 04 00 00 00 02 80 08 00 04 00 00 00 06 80 06 00 04 00 00 00 01 00 10 00 04 00 00 2e e0 80 55 00 04 00 01 00 02" 
            # Allocated Request Bandwidth:350
            $EncodedText = "00 03 00 28 21 12 a4 42 a2 3f 22 ce 46 fe ee b8 e7 0d 0c 91 00 0f 00 04 72 c6 4b c6 80 08 00 04 00 00 00 06 80 06 00 04 00 00 00 01 00 10 00 04 00 00 01 5e 80 55 00 04 00 00 00 02"
            # Allocated Response Bandwidth:350 + realm with nonc
            # $EncodedText = "00 03 00 b2 21 12 a4 42 1e 89 49 05 a2 33 1a f4 c0 71 30 ac 00 0f 00 04 72 c6 4b c6 80 08 00 04 00 00 00 06 80 06 00 04 00 00 00 01 00 10 00 04 00 00 01 5e 80 55 00 04 00 00 00 02 80 95 00 08 6e 43 d8 45 47 2d 88 1f 00 14 00 14 b0 c6 fa ca 72 f4 50 9c 3f 2c ad ea 19 0a a1 ac e5 cd 93 06 00 15 00 0a 22 72 74 63 6d 65 64 69 61 22 00 06 00 30 04 00 00 1c 96 88 63 6f 27 be 5b ef f8 38 72 92 ba f3 99 40 b8 83 98 dd 00 00 00 00 61 77 9f 8a 7c 4c 24 65 41 d3 a2 89 34 93 19 f6 36 dc 8b 60 00 08 00 20 b8 fe a5 f7 25 06 c2 32 b7 e6 e9 7a 3a e2 d7 bc 97 22 44 13 2f 3e df 7e 24 05 75 cc 0d ed db 9a"
            $EncodedText =  $EncodedText  -split ' ' | ForEach-Object { [Convert]::ToByte($_, 16) }
            Write-UTCLog "Send Message    : STUN FAKE MESSAGE 00 03 00 30 21 12 a4 ... " -color yellow
      }
      else {
            $EncodedText = [Text.Encoding]::ASCII.GetBytes($Message) 
            Write-UTCLog "Send Message    : $($Message)" -color yellow
      }
      
      $startTime = get-date 
      $Socket.Send($EncodedText, $EncodedText.Length, $EndPoints) | Out-Null
      
      try
      {
            $ReceMessage = [text.encoding]::ascii.getstring($Socket.Receive([ref]$EndPoints))
            $endTime = get-date
            $totalSeconds = "{0:N4}" -f ($endTime-$startTime).TotalSeconds
            # compare $ReceMessage with $Message, write output to log file
            if ($ReceMessage -ne $Message) {
                  if ($Message -eq "STUN") {
                        $ReceMessage = "STUN FAKE MESSAGE"; $status="CompareSkip"
                  }
                  else {
                        $status="Corrupt"
                  }
                  Write-UTCLog "Receive Message : $($ReceMessage) , Latency: $($totalSeconds) s" -color Yellow
                  $logmessage = (($startTime).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss") + "," + $EndPoint + "," + $Port + "," + $ReceMessage + ","+$status+"," + $totalSeconds
                  $logmessage | Out-File $logfile -Encoding utf8 -append
                  if ([string]::IsNullOrEmpty($aikey)) {
                        if ($debug) {Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"}
                    } 
                    else 
                    {
                        if ($debug) {Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"}
                        Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{PreciseTimeStamp=($startTime).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss");Server=$EndPoint;Port=$Port;Message=$Message;Result=$status;Latency=$totalSeconds} -logpath $logpath
                  }
            }
            else {
                  Write-UTCLog "Receive Message : $($ReceMessage) , Latency: $($totalSeconds) s" -color Green
                  $logmessage = (($startTime).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss") + "," + $EndPoint + "," + $Port + "," + $ReceMessage + ",OK," + $totalSeconds
                  $logmessage | Out-File $logfile -Encoding utf8 -append
                  if ([string]::IsNullOrEmpty($aikey)) {
                        if ($debug) {Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"}
                    } 
                    else 
                    {
                        if ($debug) {Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"}                  
                        Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{PreciseTimeStamp=($startTime).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss");Server=$EndPoint;Port=$Port;Message=$Message;Result="OK";Latency=$totalSeconds} -logpath $logpath
                    }
            }
            
      }
      catch [System.Net.Sockets.SocketException]
      {
            Write-UTCLog "Receive Message : Error, timeout $timeout (ms)" -color "red";
            $logmessage = (($startTime).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")  + "," + $EndPoint + "," + $Port + "," + $Message + ",NoResponse(Timeout $timeout (ms)),-"
            $logmessage | Out-File $logfile -Encoding utf8 -append
            if ([string]::IsNullOrEmpty($aikey)) {
                  if ($debug) {Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"}
              } 
              else 
              {
                  if ($debug) {Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"}
                  Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{PreciseTimeStamp=($startTime).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss");Server=$EndPoint;Port=$Port;Message=$Message;Result="NoResponse(Timeout $timeout (ms))";Latency="-"} -logpath $logpath
              }
      }
      $Socket.Close() 
} 

Write-UTCLog "Session Started" -color Yellow
Write-UTCLog "Server : $($Server)     Port : $($Port)   N(repeat) : $($n)  Payloadsize : $($payloadsize)" -color Green

$scriptname = $MyInvocation.MyCommand.Name


# create header of log file
$logfile = $logpath + "\udping_" + $Server + "_" + $port + "_" + (get-date).ToUniversalTime().ToString("yyyyMMdd_HHmmss") + ".csv"
$header= "timestamp,Server,Port,Message,Result,Latency"
$header | Out-File $logfile -Encoding utf8 -append
Write-UTCLog "Log file : $logfile" -color Green

if ($n -eq 0)
{
      while ($true)
      {
            if ($payloadsize -eq 1314)
            {
                $message = "STUN"
            }
            else {
                #create a message payload with random characters
                for ($j=1;$j -le $payloadsize;$j++) {  $message += (65..90) | Get-Random | % {[char]$_}}
            }
            Send-UdpDatagram -EndPoint $Server -Port $port -Message $message -timeout $timeout -logfile $logfile
            Start-Sleep -Milliseconds $wait
            $message=""
      }
}
else {
      for ($i=1;$i -le $n; $i++) {
        if ($payloadsize -eq 1314)
        {
            $message = "STUN"
        }
        else {
            #create a message payload with random characters
            for ($j=1;$j -le $payloadsize;$j++) {  $message += (65..90) | Get-Random | % {[char]$_}}
        }
        $receMessage=Send-UdpDatagram -EndPoint $Server -Port $port -Message $message -timeout $timeout  -logfile $logfile
        Start-Sleep -Milliseconds $wait
        $message=""
      }
}

