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
# or use python sample https://github.com/wangyu-/UDPping/blob/master/udpping.py
##################################################################################

Param (
    [string]$Server="127.0.0.1",
    [int]$port=9030,
    [int]$timeout=1000, #timeout in ms
    [int]$wait=1000, #wait time in ms
    [ValidateRange(0,99999)][int]$n=10, #0 forever
    [ValidateRange(5,10000)][Int]$payloadsize=10,
    [string]$logpath=$env:temp # log file path and log filename will be udping_$server_$port_yyyymmdd_hhmmss.log
)

#Send-UdpDatagram -EndPoint $Endpoint -Port $port -Message "test.mymetric:0|c"      
Function Write-UTCLog ([string]$message,[string]$color)
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
      Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
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
            }
            else {
                  Write-UTCLog "Receive Message : $($ReceMessage) , Latency: $($totalSeconds) s" -color Green
                  $logmessage = (($startTime).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss") + "," + $EndPoint + "," + $Port + "," + $ReceMessage + ",OK," + $totalSeconds
                  $logmessage | Out-File $logfile -Encoding utf8 -append
            }
      }
      catch [System.Net.Sockets.SocketException]
      {
            Write-UTCLog "Receive Message : Error, timeout 1 second" -color "red";
            $logmessage = (($startTime).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")  + "," + $EndPoint + "," + $Port + "," + "Respnose timeout $timeout (ms)" + ",NoResponse,-"
            $logmessage | Out-File $logfile -Encoding utf8 -append
      }
      $Socket.Close() 
} 

Write-UTCLog "Session Started" -color Yellow
Write-UTCLog "Server : $($Server)     Port : $($Port)   N(repeat) : $($n)  Payloadsize : $($payloadsize)" -color Green

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

