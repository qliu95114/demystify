param (
        [parameter(Mandatory = $false, HelpMessage = "Enter the tcp port you want to use to listen on, for example 3389", parameterSetName = "TCP")]
        [ValidatePattern('^[0-9]+$')]
        [ValidateRange(0, 65535)]
        [int]$TCPPort,

        [parameter(Mandatory = $false, HelpMessage = "Enter the udp port you want to use to listen on, for example 3389", parameterSetName = "UDP")]
        [ValidatePattern('^[0-9]+$')]
        [ValidateRange(0, 65535)]
        [int]$UDPPort
    )

Function Write-UTCLog ([string]$message,[string]$color)
{
        $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
        $logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}


#Test if TCP port is already listening port before starting listener
if ($TCPPort) {
    $Global:ProgressPreference = 'SilentlyContinue' #Hide GUI output
    $testtcpport = Test-NetConnection -ComputerName localhost -Port $TCPPort -WarningAction SilentlyContinue -ErrorAction Stop
    if ($testtcpport.TcpTestSucceeded -ne $True) {
        Write-UTCLog ("TCP port {0} is available, continuing..." -f $TCPPort) -Color Green
    }
    else {
        Write-UTCLog ("TCP Port {0} is already listening, aborting..." -f $TCPPort) -color Yellow
        return
    }

    #Start TCP Server
    $ipendpoint = new-object System.Net.IPEndPoint([ipaddress]::any, $TCPPort) 
    $listener = new-object System.Net.Sockets.TcpListener $ipendpoint
    $listener.start()
    Write-UTCLog ("Now listening on TCP port {0}, press Escape to stop listening" -f $TCPPort) -Color Green
    while ( $true ) {
        if ($host.ui.RawUi.KeyAvailable) {
            $key = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown")
            if ($key.VirtualKeyCode -eq 27 ) { 
                $listener.stop()
                Write-UTCLog ("Stopped listening on TCP port {0}" -f $TCPPort) -color Green
                return
            }
        }
    }
}
    

#Test if UDP port is already listening port before starting listener
if ($UDPPort) {
    try {
        # Create a UDP client object
        $UdpObject = New-Object system.Net.Sockets.Udpclient($UDPPort)
        # Define connect parameters
        $computername = "localhost"
        $UdpObject.Connect($computername, $UDPPort)    
    
        # Convert current time string to byte array
        $ASCIIEncoding = New-Object System.Text.ASCIIEncoding
        $Bytes = $ASCIIEncoding.GetBytes("$((get-date).ToUniversalTime()).ToString('yyyy-MM-dd HH:mm:ss')")
        # Send data to server
        [void]$UdpObject.Send($Bytes, $Bytes.length)    
    
        # Cleanup
        $UdpObject.Close()
        Write-UTCLog ("UDP port {0} is available, continuing..." -f $UDPPort) -Color Green
    }
    catch {
        Write-UTCLog ("UDP Port {0} is already listening, aborting..." -f $UDPPort) -color Yellow
        return
    }

    #Start UDP Server
    #Used procedure from https://github.com/sperner/PowerShell/blob/master/UdpServer.ps1
    $endpoint = new-object System.Net.IPEndPoint( [IPAddress]::Any, $UDPPort)
    $udpclient = new-object System.Net.Sockets.UdpClient $UDPPort
    Write-UTCLog ("Now listening on UDP port {0}, press Escape to stop listening" -f $UDPPort) -Color Green
    while ( $true ) {
        if ($host.ui.RawUi.KeyAvailable) {
            $key = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown")
            if ($key.VirtualKeyCode -eq 27 ) { 
                $udpclient.Close()
                Write-UTCLog ("Stopped listening on UDP port {0}" -f $UDPPort) -Color Green
                return
            }
        }

        if ( $udpclient.Available ) {
            $content = $udpclient.Receive( [ref]$endpoint )
            Write-UTCLog "$($endpoint.Address.IPAddressToString):$($endpoint.Port) $([Text.Encoding]::ASCII.GetString($content))" -color white
            # respone to client
            $udpclient.Send($content, $content.Length, $endpoint) | Out-Null
        }
    }
}
