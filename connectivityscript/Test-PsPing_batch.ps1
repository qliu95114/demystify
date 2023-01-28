# sample of filename.txt
# ipaddreev4:port
########################### 
#  17.171.85.7:443        #
#  52.76.10.203:2777      # 
#  193.105.74.58:8888     #  
###########################

param(
    [string]$filename="D:\temp\target.txt",
    [string]$logpath="$($env:temp)",
    [string]$aikey
)

Function Write-Log ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

#main
# PSPing.exe/PSPing64.exe local path. 

if ($env:PROCESSOR_ARCHITECTURE -match "AMD64") 
{
    Write-Verbose "x64 machine, PSPING64.exe will be used"
    $pspingFileName = "psping64.exe"
    $pspingDownloadUrl = "https://live.sysinternals.com/psping64.exe"    
}
else 
{
    Write-Verbose "x86 machine, PSPING.exe will be used"
    $pspingFileName = "psping.exe"
    $pspingDownloadUrl = "https://live.sysinternals.com/psping.exe"    
}

# setting local path to script current folder
$pspingLocalFullPath = Join-Path $PSScriptRoot $pspingFileName

# checking if PSPing/64.exe is in the script folder
If (!(Test-Path $pspingLocalFullPath -PathType Leaf))
{
    # setting local path to logpath folder to see if PSPing/64.exe is there (if not in the script folder)
    $pspingLocalFullPath = Join-Path $logpath $pspingFileName

    # checking if PSPing/64.exe is in the logpath folder (if not try to download it)
    If (!(Test-Path $pspingLocalFullPath -PathType Leaf)) 
    {
        # download from Internet.
        If (!$AsJob) 
        {   # In interactive mode, prompt user the file download. 
            # In Job mode, download directly if the file doesn't exist. 
    
            # confirm to download the PSTool.zip
            Write-host "The script will download $pspingFileName from Microsoft Systeminternals web site: $pspingDownloadUrl" -ForegroundColor Cyan
            Write-Host "Please confirm if the download is allowed: Y/N " -ForegroundColor Yellow  -NoNewline
            $keyPressed = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            # Y and Enter key are accepted to download. other keys are not.
            if (($keyPressed.VirtualKeyCode -ne 89) -and ($keyPressed.VirtualKeyCode -ne 13)) 
            {
                # Download is not allowed. 
                Write-Host $keyPressed.Character.ToString().ToUpper()  -ForegroundColor Red
                Write-Host "Download $pspingFileName is not allowed." -ForegroundColor Red
                Write-Host "Please manully download $pspingFileName from $pspingDownloadUrl and copy $pspingFileName to the same folder of this script.`n Run script again."
                Exit -1
            }
    
            Write-Host $keyPressed.Character.ToString().ToUpper()  -ForegroundColor Green
            
        }
        # Download is allowed.
        $webClient = New-Object System.Net.WebClient
        Try 
        {
            Write-Host "Downloading $pspingFileName ..." -ForegroundColor Cyan
            $webClient.DownloadFile($pspingDownloadUrl, $pspingLocalFullPath)
            Write-Host "Downloaded $pspingFileName to folder  $pspingLocalFullPath." -ForegroundColor Cyan
        }
        Catch 
        {
            Write-Host "Cannot download $pspingFileName from Internet. Make sure the Internet connection is available." -ForegroundColor Red    
            Exit -1
        }
    }
}

if (Test-path $filename)
{
    $list=get-content $filename
    Write-Log "Filename: $($filename)" "Green"
    $mypath = $MyInvocation.MyCommand.Path
    foreach ($target in $list)
    {
        Write-Log "create test thread : $($target) ..." 
        $server=$target.split(':')[0]
        $port=$target.split(':')[1]
        Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @("-NoProfile","-file","$(split-path($mypath))\Test-PSPing.ps1","-ipaddr","$($server)","-port","$($port)","-interval","5","-logpath","$($logpath)","-aikey","$($aikey)")
    }
}
else {
    Write-Log "Filename : $($filename) does not exist, please verify"  "RED"
}
