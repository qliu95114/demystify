<#
.SYNOPSIS
Import Network Trace file to Azure Data Explorer (ADX or Kusto Emulator)

.DESCRIPTION
This script converts one cap or pcap file to CSV format and can also convert all *.cap or *.pcap files in a folder to CSV files. 
It can be used with Kusto Emulator on the same machine or with a file share path. 
For Kusto Cluster, a storage container sas token can be provided to upload files. 
Table names are required, or the script will create one.

.PARAMETER -tracefolder
The name of the folder where the trace is located.

.PARAMETER -tracefile 
The name of the trace file that needs to be converted.

.PARAMETER -csvfolder
The location where the CSV file will be saved.

.PARAMETER -kustoendpoint
The Kusto endpoint, including the database name (case-sensitive).

.PARAMETER -kustotable 
The name of the Kusto table (case-sensitive).

.PARAMETER -sastoken
A valid SASTOKEN is required for Azure Storage Account at the Container level, with permissions for read/write/list.

.PARAMETER -logfile 
The default option is $($env:temp)\pcap2kusto_timestamp.log.

.EXAMPLE
convert e:\share\*.pcap to e:\share\csv\*.csv 
.\pcap2kusto.ps1 -tracefolder e:\share -tracefile *.pcap -csvfolder e:\share\csv 

convert e:\share\*.pcap to e:\share\csv\*.csv and import to local kusto cluster
.\pcap2kusto.ps1 -tracefolder e:\share -tracefile *.pcap -csvfolder e:\share\csv -kustoendpoint http://localhost:8080/public -kustotable mytablename

convert e:\share\*.pcap to e:\share\csv\*.csv and import to local kusto cluster, drop / create new table -newtable
.\pcap2kusto.ps1 -tracefolder e:\share -tracefile *.pcap -csvfolder e:\share\csv -kustoendpoint http://localhost:8080/public -kustotable mytablename

convert e:\share\*.pcap to e:\share\csv\*.csv , use storage account and import to kusto, get one from http://aka.ms/kustofree
.\pcap2kusto.ps1 -tracefolder e:\share -tracefile *.pcap -csvfolder e:\share\csv -kustoendpoint "https://kvcy2wf2t0n1epwsyck1cj.australiaeast.kusto.windows.net/public;AAD Federated Security=True" -kustotable pcap2kustotable  -sastoken <SAS>

convert e:\share\*.pcap to e:\share\csv\*.csv , use storage account and import to kusto, drop / create new table
.\pcap2kusto.ps1 -tracefolder e:\share -tracefile *.pcap -csvfolder e:\share\csv -kustoendpoint "https://kvcy2wf2t0n1epwsyck1cj.australiaeast.kusto.windows.net/public;AAD Federated Security=True" -kustotable pcap2kustotable  -sastoken <SAS> -newtable

Create kusto table 
.drop table pcap2kustotable
.create table pcap2kustotable (framenumber:long,frametime:string,DeltaDisplayed:string,Source:string,Destination:string,ipid:string,Protocol:string,tcpseq:string,tcpack:string,Length:int,tcpsrcport:int,tcpdstport:int,udpsrcport:int,udpdstport:int,tcpackrtt:string,frameprotocol:string,Info:string,ethsrc:string,ethdst:string,SourceV6:string,DestinationV6:string,ipProtocol:string)
#>

<#
author: qliu 
2023-03-25, Fix a few bugs & comments 
2023-03-18, FIRST VERSION
#>

Param (
    [string]$tracefolder="e:\share",
	[string]$tracefile="*.pcap",
	[string]$csvfolder="$($tracefolder)\csv",
    [switch]$csvoverwrite, #if target local:csv already exist, skip by default 
	[string]$kustoendpoint, # http://localhost:8080/public
	[string]$kustotable, # 
	# table naming rule https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/schema-entities/entity-names
	[string]$sastoken,
    [string]$kustocli="D:\Source_git\Script\KustoCLI\Kusto.Cli.exe",
    [string]$tsharkcli="c:\program files\wireshark\tshark.exe",
    [switch]$newtable,
    [switch]$debug  #if debug is enable, will output function callname
)

Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

Function pcap2csv ([string]$pcapfile,[string]$csvfile,[string]$jobid)  #FlatJSON 
{
    if ($debug) {Write-UTCLog " ++function:pcap2csv " "cyan"}
    
    if (Test-path $csvfile)
    {
        if ($csvoverwrite) { remove-item $csvfile -Force} 
        else 
        {
            Write-UTCLog "  ++csv: $($csvfile) already exist, skipping" "Yellow"
            return
        }
    }
    $pcapfilename=(Get-ChildItem $pcapfile).basename
    $cmdtshark="""$($tsharkcli)"" -r ""$($pcapfile)"" -T fields -e frame.number -e frame.time_epoch -e frame.time_delta_displayed -e ip.src -e ip.dst -e ip.id -e _ws.col.Protocol -e tcp.seq -e tcp.ack -e frame.len -e tcp.srcport -e tcp.dstport -e udp.srcport -e udp.dstport -e tcp.analysis.ack_rtt -e frame.protocols -e _ws.col.Info -e eth.src -e eth.dst -e ipv6.src -e ipv6.dst -e ip.proto -e dns.id -e ip.ttl -e ip.flags -e tcp.flags -E header=y -E separator=, -E quote=d > ""$($csvfile)"""    <# Action when all if and elseif conditions are false #>
    $cmdtshark|out-file "$($env:temp)\$($pcapfilename)_$($jobid)_0_pcap2csv.cmd" -Encoding ascii
    if ($debug) 
        {   
            Write-UTCLog "  ++JobCMD : $($env:temp)\$($pcapfilename)_$($jobid)_0_pcap2csv.cmd" "cyan"
            Write-UTCLog "  ++ $cmdtshark " "cyan"
        }
    if ($debug) {
        Invoke-Expression "cmd /c $($env:temp)\$($pcapfilename)_$($jobid)_0_pcap2csv.cmd"
    }
    else {
        Invoke-Expression "cmd /c $($env:temp)\$($pcapfilename)_$($jobid)_0_pcap2csv.cmd" | Out-Null
    }
    Write-UTCLog "  ++csv: $($csvfile) convert complete" 
    return $result
}

function CSVtoKustoEmulator([string]$csvfile,[string]$kustoendpoint,[string]$kustotable,[string]$jobid)
{
    if ($debug) {Write-UTCLog " ++function:CSVtoKustoEmulator " "Cyan"}
    #create ingress kql file
    $csvfilename=(Get-ChildItem $csvfile).fullname

    # replace "-" "." "," with _ in table name
    $kustotable=$kustotable.replace("-","_")
    $kustotable=$kustotable.replace(".","_")
    $kustotable=$kustotable.replace(",","_")

    #generate kql file
    $kqlcsv=".ingest into table $($kustotable) (@""$($csvfilename)"") with (format='csv',ignoreFirstRecord=true)"
    if ($debug) {Write-UTCLog "  ++kql: $($kqlcsv)"  "cyan"}
    $kqlcsv|out-file "$($env:temp)\$($(Get-ChildItem $csvfile).BaseName)_$($jobid)_1_ingress.kql" -Encoding ascii

    $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($env:temp)\$($(Get-ChildItem $csvfile).BaseName)_$($jobid)_1_ingress.kql"""
    if ($debug) {Write-UTCLog "  ++kqlcmd: $($kqlcmd)" "cyan"}
    Write-UTCLog "  +++ (Kusto.Cli) (Local) ingress table $($kustotable) from ($($csvfilename))" -color "Green"

    #execute kusto
    if ($debug) {Invoke-Expression  $kqlcmd} else {Invoke-Expression  $kqlcmd| Out-Null}    
}

function CSVtoContainer([string]$csvfile,[string]$sastoken,[string]$jobid)
{
    if ($debug) {Write-UTCLog " +++function:CSVtoContainer " "cyan"}
    if (-not ((get-command "azcopy").count -eq 0)) #if we have azcopy installed or use $useWebClient switch is enabled, fall back to System.Net.WebClient download. otherwise use azcopy to speed up the download performance
    {
        Write-UTCLog "  +++ (azcopy10) upload $csvfile " -color "Green"
        $cmdazcopy="azcopy copy ""$($csvfile)"" ""$($sastoken)"" --overwrite=ifSourceNewer"  
        if ($debug) {Invoke-Expression $cmdazcopy} else {Invoke-Expression $cmdazcopy|Out-Null}
    }
    else {
        Write-UTCLog "  +++ azcopy(10) cannot be found, please review installation and continue" -color "Red"
        return
    }
}
function CSVtoKustoCluster([string]$csvfile,[string]$kustoendpoint,[string]$kustotable,[string]$sastoken,[string]$jobid)
{
    if ($debug) {Write-UTCLog  " +++function:CSVtoKustoCluster " "cyan"}
    #use azcopy copy CSV to storage account
    CSVtoContainer -csvfile $csvfile -sastoken $sastoken -jobid $jobid

    #create ingress kql file
    $csvfilename=(Get-ChildItem $csvfile).name

    # replace "-" "." "," with _ in table name
    $kustotable=$kustotable.replace("-","_")
    $kustotable=$kustotable.replace(".","_")
    $kustotable=$kustotable.replace(",","_")
    
    #generate SAS token and kql file
    $csvsas="$($sastoken.split('?')[0])/$($csvfilename)?$($sastoken.split('?')[1])"  
    $kqlcsvblob=".ingest into table $($kustotable) (@""$($csvsas)"") with (format='csv',ignoreFirstRecord=true)"
    if ($debug) {Write-UTCLog "  ++kql: $($kqlcsvblob)"  "cyan"}
    $kqlcsvblob|out-file "$($env:temp)\$($(Get-ChildItem $csvfile).BaseName)_$($jobid)_1_ingress.kql" -Encoding ascii
    $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($env:temp)\$($(Get-ChildItem $csvfile).BaseName)_$($jobid)_1_ingress.kql"""
    if ($debug) {Write-UTCLog "  ++kqlcmd: $($kqlcmd)" "cyan"}
    Write-UTCLog "  +++ (Kusto.Cli) (ADX) ingress table $($kustotable) from blob $($csvfilename)" -color "Green"

    #execute kusto
    if ($debug) {Invoke-Expression  $kqlcmd} else {Invoke-Expression  $kqlcmd| Out-Null}
}

function pcap2kustocore([string]$pcapfile,[string]$csvfile,[string]$kustoendpoint,[string]$kustotable,[string]$sastoken) # this handle one file only
{
    if ($debug) {Write-UTCLog  " +function:pcap2kustocore '$($pcapfile)'" "cyan"}
    
    #config capinfos 
    set-alias capinfos "c:\Program Files\Wireshark\capinfos.exe"
    $pcapacketcount=[int][regex]::Match(((capinfos $pcapfile)|Select-String "Number of Packets ="), '\d+').Value

    #determine $pcapfile packet count if this is > 1500000, we will split orginial file into multiple and once it is complete the orginial file will get removed. 
    if ($pcapacketcount -le 1500000)
    {
        $jobid= New-Guid
        pcap2csv -pcapfile $pcapfile -csvfile $csvfile -jobid $jobid
        if ([string]::IsNullOrEmpty($kustoendpoint))
        {
            #Write-UTCLog " +KustoEndpoint is not specified, only pcap2csv only" "Red"
            return
        }
        else {
            if ($kustoendpoint.contains("kusto.windows.net") -or $kustoendpoint.contains("kusto.chinacloudapi.cn"))
            {
                if ([string]::IsNullOrEmpty($sastoken))
                {
                    Write-UTCLog " +$($kustoendpoint) is used, but SAS token is not specified, existing..." "Red"
                }
                else {
                    CSVtoKustoCluster -csvfile $csvfile -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid #
                }
            }
            else {
                CSVtoKustoEmulator -csvfile $csvfile -kustoendpoint $kustoendpoint -kustotable $kustotable -jobid $jobid 
            }
        }
    }
    else {
        # split pcap file into multiple pcap files. 
        Write-UTCLog " $($pcapfile) has more than 1.5M packets, spliting..." "Yellow"
        Set-Alias editcap "c:\Program Files\Wireshark\editcap.exe"
        $splitcmd="editcap -c 1500000 $($pcapfile) $(Split-Path -Parent -path $pcapfile)\$(Split-Path -Leaf -path $pcapfile)"
        Invoke-Expression $splitcmd
        Write-UTCLog " splitcmd: $($splitcmd)" "Yellow"
        $filename = Split-Path -Leaf -path $pcapfile
        $pcapfiles=Get-ChildItem "$(Split-Path -Parent -path $pcapfile)\$([System.IO.Path]::GetFileNameWithoutExtension($filename))_*.*"
        
        if ($pcapfiles.count -ge 1) 
        {
            Write-UTCLog " Deleting $($pcapfile), we already have splitted files $($pcapfiles.count)" "Red"
            Remove-Item $pcapfile -Force # remove the original pcap file as we have split files
        }

        $k=0
        foreach ($pcap in $pcapfiles)
        {
            $k++
            $jobid= New-Guid
            Write-UTCLog "  +++pcap2csv(split): $($k)/$($pcapfiles.count) - $($pcap) " "Yellow"
            pcap2csv -pcapfile $pcap -csvfile "$(Split-Path -Parent -path $csvfile)\$($pcap.basename).csv" -jobid $jobid
            if ([string]::IsNullOrEmpty($kustoendpoint))
            {
                #if ($debug) {Write-UTCLog " +KustoEndpoint is not specified, only pcap2csv only" "Red"}
            }
            else {
                if ($kustoendpoint.contains("kusto.windows.net") -or $kustoendpoint.contains("kusto.chinacloudapi.cn"))
                {
                    if ([string]::IsNullOrEmpty($sastoken))
                    {
                        Write-UTCLog " +$($kustoendpoint) is used, but SAS token is not specified, existing..." "Red"
                    }
                    else {
                        CSVtoKustoCluster -csvfile "$(Split-Path -Parent -path $csvfile)\$($pcap.basename).csv" -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid #
                    }
                }
                else {
                    CSVtoKustoEmulator -csvfile "$(Split-Path -Parent -path $csvfile)\$($pcap.basename).csv" -kustoendpoint $kustoendpoint -kustotable $kustotable -jobid $jobid 
                }
            }
        }

    }

}


#Main Program
#precheck enviornment tshark.exe and kustocli.exe

$tracefolder=$tracefolder.TrimEnd("\")  #remove extra "\"
$csvfolder=$csvfolder.TrimEnd("\") #remove extra "\"

#determine target folder exist or not
if (-not (Test-path $csvfolder))
{
    Write-UTCLog "'$($csvfolder)' does not exsit! Creating" "Yellow"
    mkdir $csvfolder 
}

# check tshark.exe exist, 
if (-not (Test-Path $tsharkcli))
{
    Write-UTCLog "'$($tsharkcli)' wasn't found, download and install Wireshark 3.4.9" "red"
    # Download the Wireshark installer
    (New-Object System.Net.WebClient).DownloadFile("https://www.wireshark.org/download/win64/all-versions/Wireshark-win64-3.4.9.exe", "$($env:temp)\wireshark.exe")

    # Install Wireshark silently
    $arguments = "/S /D=`"$($env:ProgramFiles)\Wireshark`""
    Start-Process -FilePath "$($env:temp)\wireshark.exe" -ArgumentList $arguments -Wait

    # Clean up the temporary files
    Remove-Item -Path "$($env:temp)\wireshark.exe"

    if (Test-Path $tsharkcli)
    {
        #config tshark alias and we can use in current session
        Set-Alias -Name tshark -Value $tsharkcli        
        Write-UTCLog " $((tshark --version)[0]) is installed."  "Green"
    }
    else {
        Write-UTCLog " tshark installation failed."  "Red"
    }
}
else {
    Set-Alias -Name tshark -Value $tsharkcli        
    Write-UTCLog " $((tshark --version)[0]) is installed.  Location: '$($tsharkcli)'"  "Green"
}


# Check if AzCopy is already installed
if (-not (Get-Command azcopy -ErrorAction SilentlyContinue)) {

    Write-UTCLog "  azcopy wasn't found, download & unzip azcopy" -color "Yellow"
    # Download the AzCopy executable
    (New-Object System.Net.WebClient).DownloadFile("https://aka.ms/downloadazcopy-v10-windows", "$($env:temp)\azcopy.zip")
    
    # Extract the AzCopy executable
    Expand-Archive -Path "$($env:temp)\azcopy.zip" -DestinationPath $env:temp -Force

    # Clean up the temporary files
    Remove-Item -Path "$($env:temp)\azcopy.zip"

    #config azcopy alias and we can use in current session
    Set-Alias -Name azcopy -Value (Get-ChildItem "$($env:temp)\azcopy.exe" -Recurse)[0].FullName

    # Verify that AzCopy is installed
    if (Get-Command azcopy -ErrorAction SilentlyContinue) {
        Write-UTCLog " $(azcopy --version) is installed."  "Green"
    } else {
        Write-UTCLog " azcopy installation failed."  "Red"
    }
}
else {
    Write-UTCLog " $(azcopy --version) is installed."  "Green"
}

# Check if KustoCli is already installed
if ([string]::IsNullOrEmpty($kustoendpoint))
{
    Write-UTCLog " -KustoEndpoint is not specified, pcap2csv only" "Red"
}
else {
    if (-not (Test-path $kustocli))
    {
        Write-UTCLog "'$($kustocli)' cannot be found, please install KustoCLI https://www.nuget.org/packages/Microsoft.Azure.Kusto.Tools/#release-body-tab and continue" "red"
        $kustoendpoint = $null
        $kustotable = $null
        $sastoken = $null
        $newtable = $false
    }
    else {
        if (($newtable) -and (![string]::IsNullOrEmpty($kustotable)))
        {
            $globalid=New-Guid
            $kqlnewtable0=".drop table $($kustotable)"
            $kqlnewtable1=".create table $($kustotable) (framenumber:long,frametime:string,DeltaDisplayed:string,Source:string,Destination:string,ipid:string,Protocol:string,tcpseq:string,tcpack:string,Length:int,tcpsrcport:int,tcpdstport:int,udpsrcport:int,udpdstport:int,tcpackrtt:string,frameprotocol:string,Info:string,ethsrc:string,ethdst:string,SourceV6:string,DestinationV6:string,ipProtocol:string,dnsid:string,ipTTL:string,ipFlags:string,tcpFlags:string)"
            $kqlnewtable0|out-file "$($env:temp)\$($globalid)_0_createtable.kql" -Encoding ascii
            $kqlnewtable1|out-file "$($env:temp)\$($globalid)_0_createtable.kql" -Encoding ascii -Append
            $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($env:temp)\$($globalid)_0_createtable.kql"""
            Write-UTCLog " (Kusto.Cli.exe) create new table $($kustotable) @ $($kustoendpoint)" -color "Green"
            if ($debug) {Write-UTCLog "  ++kqlcmd: $($kqlcmd)" "cyan"}
            #execute kusto
            if ($debug) {Invoke-Expression  $kqlcmd} else {Invoke-Expression  $kqlcmd| Out-Null}
        }
        else {
            if ([string]::IsNullOrEmpty($kustotable))
            {
                Write-UTCLog " -Kustotable is missing, please check... " "Red"
                exit
            }
            else {
                Write-UTCLog " Assume table:$($kustotable) exist. The script may fail if table does not exist..." "Yellow"
            }
        }

    }
}

if (Test-Path $tracefolder)  #validate
{
	if ($tracefile.contains("*") -or $tracefile.contains("?")) {
            Write-UTCLog "Generate a list of $($tracefile) under $($tracefolder) ..."
            $pcapfilelist=(Get-ChildItem "$($tracefolder)\$($tracefile)" -Recurse)

            if ($pcapfilelist.count -ne 0)
            {
                Write-UTCLog " Pcap $($tracefolder)\$($tracefile) Total : $($pcapfilelist.count) File(s)" "Yellow"
                [Int64]$totalsize=0
                foreach ($pcapfile in $pcapfilelist)
                {
                    Write-UTCLog "$($pcapfile),$($pcapfile.Length)"
                    $totalsize+=$pcapfile.Length
                }
                Write-UTCLog " Pcap Files (Total): $($pcapfilelist.count) , File Size (Total): $($totalsize)bytes ($("{0:F2}" -f $($totalsize/1024/1024)) MBs), Required Disk Space (Estimate): ($("{0:F2}" -f $($totalsize/1024/1024*2.40)) MBs) " "Yellow"
                
                $j=1
                foreach ($pcapfile in $pcapfilelist)
                {
                    Write-UTCLog " Processing $($j)/$($pcapfilelist.count) : $($pcapfile.FullName) " "Green"
                    $csvfilename="$($pcapfile.basename).csv"
                    pcap2kustocore -pcapfile "$($pcapfile.FullName)" -csvfile "$($csvfolder)\$($csvfilename)" -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken
                    $j++
                    #PT1H2CSV -srcpt1h $nsgfile.FullName -csvfile $destfile
                    #PT1H2CSV_Memory -srcpt1h $nsgfile.FullName -csvfile $destfile2
                }
            }
            else {
                Write-UTCLog " Pcap $($tracefile)\$($tracefile) Total : $($pcapfilelist.count) File(s) , existing... " "Red"
            }        
        }
    else {
        if (Test-Path "$($tracefolder)\$($tracefile)"){
            $pcapfile=Get-ChildItem "$($tracefolder)\$($tracefile)"
            $csvfilename="$($pcapfile.basename).csv"
            Write-UTCLog " Pcap File : 1, File Size : $($pcapfile.Length)bytes ($("{0:F2}" -f $($pcapfile.Length/1024/1024)) MBs), Required Disk Space (Estimate): $("{0:F2}" -f $($pcapfile.Length/1024/1024*2.40)) MBs " "Yellow"
            Write-UTCLog "$($pcapfile),$($pcapfile.Length)"
            pcap2kustocore -pcapfile "$($tracefolder)\$($tracefile)" -csvfile "$($csvfolder)\$($csvfilename)" -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken
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