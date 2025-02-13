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
    [ValidateRange(5,10000)][Int]$payloadsize=10,
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
      $EncodedText = [Text.Encoding]::ASCII.GetBytes($Message) 
      Write-UTCLog "Send Message    : $($Message)" -color yellow
      $startTime = get-date 
      $Socket.Send($EncodedText, $EncodedText.Length, $EndPoints) | Out-Null
      
      try
      {
            $ReceMessage = [text.encoding]::ascii.getstring($Socket.Receive([ref]$EndPoints))
            $endTime = get-date
            $totalSeconds = "{0:N4}" -f ($endTime-$startTime).TotalSeconds
            # compare $ReceMessage with $Message, write output to log file
            if ($ReceMessage -ne $Message) {
                  Write-UTCLog "Receive Message : $($ReceMessage) , Latency: $($totalSeconds) s" -color Yellow
                  $logmessage = (($startTime).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss") + "," + $EndPoint + "," + $Port + "," + $ReceMessage + ",Corrupt," + $totalSeconds
                  $logmessage | Out-File $logfile -Encoding utf8 -append
                  if ([string]::IsNullOrEmpty($aikey)) {
                        if ($debug) {Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"}
                    } 
                    else 
                    {
                        if ($debug) {Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"}
                        Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{PreciseTimeStamp=($startTime).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss");Server=$EndPoint;Port=$Port;Message=$Message;Result="Corrupt";Latency=$totalSeconds} -logpath $logpath
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
                  Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{PreciseTimeStamp=($startTime).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss");Server=$EndPoint;Port=$Port;Message=$Message;Result="NoResponse(Timeout $timeout (ms)";Latency="-"} -logpath $logpath
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
            #create a message payload with random characters
            for ($j=1;$j -le $payloadsize;$j++) {  $message += (65..90) | Get-Random | % {[char]$_}}
            Send-UdpDatagram -EndPoint $Server -Port $port -Message $message -timeout $timeout -logfile $logfile
            Start-Sleep -Milliseconds $wait
            $message=""
      }
}
else {
      for ($i=1;$i -le $n; $i++) {
            #create a message payload with random characters
            for ($j=1;$j -le $payloadsize;$j++) {  $message += (65..90) | Get-Random | % {[char]$_}}
            $receMessage=Send-UdpDatagram -EndPoint $Server -Port $port -Message $message -timeout $timeout  -logfile $logfile
            Start-Sleep -Milliseconds $wait
            $message=""
      }
}

