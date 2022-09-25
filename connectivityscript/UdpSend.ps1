############################################################################
#Author: Qing Liu, 

#Usage: 
#Output: 
#Options:

#Dependencies:
#nc -u $server 8125
############################################################################

Param (
    [string]$Endpoint="172.29.123.36",
    [int]$port=8125,
    [int]$concurrent=10,
    [int]$Repeat=100,
    [int]$RepeatDelayInSec=0,
    [ValidateRange(1,1400)][Int]$payloadsize=16
)

#Send-UdpDatagram -EndPoint $Endpoint -Port $port -Message "test.mymetric:0|c"      
Function Write-UTCLog ([string]$message,[string]$color)
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}


$ScriptBlock = { 

      Param (
            [string]$Endpoint,
            [int]$Port, 
            [int]$Repeat,
            [int]$payloadsize,
            [int]$RepeatDelayInSec
         )
     function Send-UdpDatagram
      {
            Param ([string] $EndPoint, 
            [int] $Port, 
            [string] $Message,
            [int] $repeat=1,
            [int] $RepeatDelayInSec)

            $IP = [System.Net.Dns]::GetHostAddresses($EndPoint) 
            $Address = [System.Net.IPAddress]::Parse($IP) 
            $EndPoints = New-Object System.Net.IPEndPoint($Address, $Port) 
            $Socket = New-Object System.Net.Sockets.UDPClient 
            $EncodedText = [Text.Encoding]::ASCII.GetBytes($Message) 
            for ($i=1 ; $i -le $repeat;$i++) 
            {
                  $SendMessage = $Socket.Send($EncodedText, $EncodedText.Length, $EndPoints) 
                  Start-Sleep $RepeatDelayInSec
            }     
            $Socket.Close() 
      } 
      
      for ($j=1;$j -le $payloadsize;$j++) {  $message += (65..90) | Get-Random | % {[char]$_}}
      Send-UdpDatagram -EndPoint $Endpoint -Port $port -Message $message -repeat $repeat -RepeatDelayInSec $RepeatDelayInSec
}

# Create session state
$myString = "this is session state!"
$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$sessionstate.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "myString" ,$myString, "example string"))
   
# Create runspace pool consisting of $numThreads runspaces
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $concurrent, $sessionState, $Host)
$RunspacePool.Open()

Write-UTCLog "Session Started" -color Yellow
Write-UTCLog "Server : $($Endpoint)     Port : $($Port)" -color Green
Write-UTCLog "Config Concurrent : $($Concurrent)   Repeat (per session) : $($Repeat)   TotalPackets : $($Concurrent * $Repeat)   payloadSize : $($payloadsize)  RepeatDelayInSec : $($RepeatDelayInSec)" -color Green

$startTime = get-date
$Jobs = @()
1..$concurrent| % {
    $Job = [powershell]::Create().AddScript($ScriptBlock).AddParameter("EndPoint", $EndPoint).AddParameter("Port", $Port).AddParameter("Repeat", $Repeat).AddParameter("payloadsize", $payloadsize).AddParameter("RepeatDelayInSec", $RepeatDelayInSec)
    $Job.RunspacePool = $RunspacePool
    $Jobs += New-Object PSObject -Property @{
      RunNum = $_
      Job = $Job
      Result = $Job.BeginInvoke()
   }
   #Start-Sleep -Seconds 1
}
 
Write-Host "Waiting." -NoNewline
Do {
   Write-Host "." -NoNewline
   Start-Sleep -Seconds 1
} While ( $Jobs.Result.IsCompleted -contains $false) #Jobs.Result is a collection

Write-Host "."
$endTime = get-date
$totalSeconds = "{0:N4}" -f ($endTime-$startTime).TotalSeconds
$PacketsPerSeconds = "{0:n0}" -f $($Concurrent * $Repeat /$totalSeconds)
$SpeedInBits= "{0:n2}" -f $($Concurrent * $Repeat * ($payloadsize+42) /$totalSeconds *8 )
$SpeedInKBits= "{0:n2}" -f $($Concurrent * $Repeat * ($payloadsize+42) /$totalSeconds/1024 *8)
$SpeedInMBits= "{0:n2}" -f $($Concurrent * $Repeat * ($payloadsize+42) /$totalSeconds/1024/1024 *8)
Write-UTCLog "Completed in $totalSeconds seconds, $($PacketsPerSeconds) Packets/s, $($SpeedInBits) bits/s , $($SpeedInKBits) Kbits/s , $($SpeedInMBits) Mbits/s " -color Green