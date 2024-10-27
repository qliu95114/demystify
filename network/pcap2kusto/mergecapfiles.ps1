<#
.SYNOPSIS
Merge network trace file under one folder 

.DESCRIPTION
Merge *.cap file to one under one folder 

.PARAMETER -tracefolder
The folder name where trace located 

.PARAMETER -tracefile 
The trace file that need be converted.

.PARAMETER -targetfile
give the file name to be saved

.EXAMPLE
covert e:\share\*.pcap to e:\share\csv\*.csv 
.\mergecapfiles.ps1 -tracefolder e:\share -tracefile *.pcap -targetfile myfile.pcap

<#
author: qliu 
2023-03-25, FIRST VERSION
#>

Param (
    [string]$tracefolder="e:\share",
	[string]$tracefile="*.pcap",
	[Parameter(Mandatory=$true)][string]$targetfile,
    [string]$mergecapcli="c:\Program Files\Wireshark\mergecap.exe"
)

Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

#Main Program
#precheck enviornment tshark.exe and kustocli.exe

$tracefolder=$tracefolder.TrimEnd("\")  #remove extra "\"

#determine target folder exist or not
if (Test-path $targetfile)
{
    $confirm = (Read-Host "File already exists. Do you want to overwrite it? (Y/N)").ToUpper()
    if ($confirm -eq "Y") {
        Remove-Item $targetfile -Force
        Write-UTCLog "File deleted..."
    }
    else {
        Write-UTCLog "Target File $($targetfile) exist, please check..."
        exit
    }
}

# check tshark.exe exist, 
if (-not (Test-Path $mergecapcli))
{
    Write-UTCLog "'$($mergecapcli)' wasn't found, download and install Wireshark 3.4.9" "red"
    # Download the Wireshark installer
    (New-Object System.Net.WebClient).DownloadFile("https://www.wireshark.org/download/win64/all-versions/Wireshark-win64-3.4.9.exe", "$($env:temp)\wireshark.exe")

    # Install Wireshark silently
    $arguments = "/S /D=`"$($env:ProgramFiles)\Wireshark`""
    Start-Process -FilePath "$($env:temp)\wireshark.exe" -ArgumentList $arguments -Wait

    # Clean up the temporary files
    Remove-Item -Path "$($env:temp)\wireshark.exe"

    if (Test-Path $mergecapcli)
    {
        #config tshark alias and we can use in current session
        Set-Alias -Name mergecap -Value $mergecapcli        
        Write-UTCLog " $((mergecap --version)[0]) is installed."  "Green"
    }
    else {
        Write-UTCLog " mergecap installation failed."  "Red"
    }
}
else {
    Set-Alias -Name mergecap -Value $mergecapcli            
    Write-UTCLog " $((mergecap --version)[0]) is installed. Location:'$($mergecapcli)'"  "Green"
}


if (Test-Path $tracefolder)  #validate
{
	if ($tracefile.contains("*") -or $tracefile.contains("?")) {
            Write-UTCLog " Generate a list of $($tracefile) under $($tracefolder) ..."
            $pcapfilelist=(Get-ChildItem "$($tracefolder)\$($tracefile)")

            if ($pcapfilelist.count -ne 0)
            {
                # display all files to be merage and total estimated disk space required
                Write-UTCLog " Pcap $($tracefolder)\$($tracefile) Total : $($pcapfilelist.count) File(s)" "Yellow"
                [Int64]$totalsize=0
                foreach ($pcapfile in $pcapfilelist)
                {
                    Write-UTCLog " GetPcapFileSize: $($pcapfile) , $($pcapfile.Length)"
                    $totalsize+=$pcapfile.Length
                }
                Write-UTCLog " Pcap Files (Total): $($pcapfilelist.count) , File Size (Total): $($totalsize)bytes ($("{0:F2}" -f $($totalsize/1024/1024)) MBs), Required Disk Space (Estimate): ($("{0:F2}" -f $($totalsize/1024/1024)) MBs) " "Yellow"

                #create a bad folder to store bad file
                $badfilefolder="$($tracefolder)\badfile"
                if (-not (Test-Path $badfilefolder)) {
                    New-Item -ItemType Directory -Path $badfilefolder | Out-Null
                }

                # initialize guid and index
                $i=1
                $guid=(New-Guid).Guid

                #merge all pcap files
                foreach ($pcapfile in $pcapfilelist)
                {
                    Write-UTCLog "  Processing $($i)/$($pcapfilelist.count): $($pcapfile.FullName) " "gray"
                    if($i -eq 1) 
                    {
                        Copy-Item $pcapfile.FullName "$($tracefolder)\$($guid)_1.pcapng"
                    }
                    else {
                        $mergecapcmd="mergecap $($tracefolder)\$($guid)_$($i-1).pcapng $($pcapfile.FullName) -w $($tracefolder)\$($guid)_$($i).pcapng"
                        Invoke-Expression $mergecapcmd
                        #verify the output file exist before delete, as in situation of bad file, mergecap will not generate output file
                        if (Test-Path "$($tracefolder)\$($guid)_$($i).pcapng") {
                            # mergecap success, delete the previous file
                            Remove-Item "$($tracefolder)\$($guid)_$($i-1).pcapng" -Force
                        }
                        else {
                            # mergecap failed, move badfile to badfilefolder and rename $i-1 to $i to skip the bad file
                            Write-UTCLog "  Bad file detected, skip the file $($pcapfile.FullName)" "Red"
                            #test-path badfilefolder exsit or not if not create it and move bad file to badfile folder
                            Move-Item $($pcapfile.FullName) "$($badfilefolder)\$($pcapfile.Name)"
                            Rename-Item "$($tracefolder)\$($guid)_$($i-1).pcapng" "$($tracefolder)\$($guid)_$($i).pcapng"
                        }
                    }
                    $i++
                }
                Move-Item "$($tracefolder)\$($guid)_$($i-1).pcapng" $($targetfile)
                Write-UTCLog " Pcap $($tracefolder)\$($tracefile) Total : $($pcapfilelist.count) File(s) merged" "Yellow"
                Write-UTCLog " Target file: $($targetfile)" "Yellow"

                # check if we have any bad file, list all children under badfile folder
                if (Test-Path $badfilefolder) {
                    $badfilelist=(Get-ChildItem $badfilefolder)
                        if ($badfilelist.count -ne 0) {
                            Write-UTCLog " Bad file(s) : $($badfilelist.count) " "Red"
                            Write-UTCLog " Bad file(s) detected, please check under $($badfilefolder)" "Red"
                            foreach ($badfile in $badfilelist) {
                                Write-UTCLog "  $($badfile.FullName)" "Red"
                            }
                        }
                        else {
                            # no bad file, remove badfile folder
                            Write-UTCLog " Bad file(s) : 0 " "Green"                        
                            remove-item $badfilefolder -Force
                        }
                }
                else {
                    <# Action when all if and elseif conditions are false #>
                }
            }
            else {
                Write-UTCLog " Did not find anything under $($tracefolder)\$($tracefile), please check..." "Yellow"
            }        
        }
    else {
        if (Test-Path "$($tracefolder)\$($tracefile)"){
            $pcapfile=Get-ChildItem "$($tracefolder)\$($tracefile)"
            $csvfilename="$($pcapfile.basename).csv"
            Write-UTCLog " Pcap File : 1, File Size : $($pcapfile.Length)bytes ($("{0:F2}" -f $($pcapfile.Length/1024/1024)) MBs), Required Disk Space (Estimate): $("{0:F2}" -f $($pcapfile.Length/1024/1024*2.2)) MBs " "Yellow"
            Write-UTCLog "$($pcapfile),$($pcapfile.Length)"
            Write-UTCLog "Just one file, no need to merge, are you kidding me..." "Cyan"
        }
        else
        {
            Write-UTCLog "$($tracefolder)\$($tracefile) does not exsit, please check"  -color "Red"  #tracefile does not exist, exit
        }
	}
} 
else {
    Write-UTCLog "$($tracefolder) does not exsit, please check"  -color "Red"  #traceFolder does not exit, exit
}
