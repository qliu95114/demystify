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

.PARAMETER -multithread
If multithread is enabled, the script will use multiple threads to convert the trace files.

.PARAMETER -logfile 
The default option is $($workingfolder)\pcap2kusto_timestamp.log.

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
.create table pcap2kustotable (framenumber:long,frametime:string,DeltaDisplayed:string,Source:string,Destination:string,ipid:string,Protocol:string,tcpseq:string,tcpack:string,Length:int,tcpsrcport:int,tcpdstport:int,udpsrcport:int,udpdstport:int,tcpackrtt:string,frameprotocol:string,Info:string,ethsrc:string,ethdst:string,SourceV6:string,DestinationV6:string,ipProtocol:string,tcpFlags:string,tcpwindowsize:int,espseq:string)
#>

<#
author: qliu 
2024-04-27, add esp.sequence
2023-07-30, Enable Multithread, add -multithread switch
2023-03-25, Fix a few bugs & comments 
2023-03-18, FIRST VERSION
#>

Param (
    [string]$tracefolder="e:\share",
	[string]$tracefile="*.pcap",
    [switch]$csvoverwrite, #if target local:csv already exist, skip by default 
	[string]$kustoendpoint, # http://localhost:8080/public
	[string]$kustotable, # 
	# table naming rule https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/schema-entities/entity-names
	[string]$sastoken,
    [string]$kustocli="D:\Source_git\Script\KustoCLI\Kusto.Cli.exe",
    [string]$tsharkcli="c:\program files\wireshark\tshark.exe",
	[string]$csvfolder="$($tracefolder)\csv",    
    [string]$workingfolder="$($csvfolder)\pcap2kusto",
    [switch]$newtable,
    [switch]$multithread,
    [switch]$debug  #if debug is enable, will output function callname
)

Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

Function pcap2csv ([string]$pcapfile,[string]$csvfile,[string]$jobid,[switch]$multithread)  #FlatJSON 
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
    $cmdtshark="""$($tsharkcli)"" -r ""$($pcapfile)"" -T fields -e frame.number -e frame.time_epoch -e frame.time_delta_displayed -e ip.src -e ip.dst -e ip.id -e _ws.col.Protocol -e tcp.seq -e tcp.ack -e frame.len -e tcp.srcport -e tcp.dstport -e udp.srcport -e udp.dstport -e tcp.analysis.ack_rtt -e frame.protocols -e _ws.col.Info -e eth.src -e eth.dst -e ipv6.src -e ipv6.dst -e ip.proto -e dns.id -e ip.ttl -e ip.flags -e tcp.flags -e tcp.window_size_value -e tcp.len -e esp.sequence -e esp.spi -e mysql.command -E header=y -E separator=/t -E quote=n > ""$($csvfile)"""    
    $cmdtshark|out-file "$($workingfolder)\$($jobid)_0_$($pcapfilename)_pcap2csv.cmd" -Encoding ascii
    if ($debug) 
        {   
            Write-UTCLog "  ++JobCMD : $($workingfolder)\$($jobid)_0_$($pcapfilename)_pcap2csv.cmd" "cyan"
            Write-UTCLog "  ++ $cmdtshark " "cyan"
        }
    
    if ($multithread)
    {
        Start-Process "cmd.exe" -ArgumentList "/c ""$($workingfolder)\$($jobid)_0_$($pcapfilename)_pcap2csv.cmd""" -WindowStyle Minimized
        Write-UTCLog "  ++csv: $($csvfile) convert started in background"  "gray"
    }
    else {
        if ($debug) {
            Invoke-Expression "cmd /c ""$($workingfolder)\$($jobid)_0_$($pcapfilename)_pcap2csv.cmd"""
        }
        else {
            Invoke-Expression "cmd /c ""$($workingfolder)\$($jobid)_0_$($pcapfilename)_pcap2csv.cmd""" | Out-Null
        }        
        Write-UTCLog "  ++csv: $($csvfile) convert complete"         
    }
    return
}

function CSVtoContainer([string]$csvfile,[string]$sastoken,[switch]$multithread)
{
    if ($debug) {Write-UTCLog " +++function:CSVtoContainer " "cyan"}
    if (-not ((get-command "azcopy").count -eq 0))
    {
        Write-UTCLog "  +++ (azcopy10) upload $csvfile " -color "Green"
        if ($multithread)
        {
            $azcopyarg="copy ""$($csvfile)"" ""$($sastoken)"" --overwrite=ifSourceNewer"  
            Start-Process "azcopy" -ArgumentList "$($azcopyarg)" -WindowStyle Minimized
            if ($debug) {Write-UTCLog "  +++: azcopy $($csvfile) in background"  "gray"}
        }
        else 
        {
            $azcopyarg="azcopy copy ""$($csvfile)"" ""$($sastoken)"" --overwrite=ifSourceNewer"  
            if ($debug) {Invoke-Expression "$($azcopyarg)"} else {Invoke-Expression "$($azcopyarg)"|Out-Null}
        }
    }
    else {
        Write-UTCLog "  +++ azcopy(10) cannot be found, please review installation and continue" -color "Red"
    }
    return
}
function CSVtoKustoCluster([string]$csvfile,[string]$kustoendpoint,[string]$kustotable,[string]$sastoken,[string]$jobid,[switch]$multithread=$false)
{
    if ($debug) {Write-UTCLog  " +++function:CSVtoKustoCluster " "cyan"}
    #use azcopy copy CSV to storage account, if this is multi-thread then skip copy as file should already be there
    if ($multithread){}else { CSVtoContainer -csvfile $csvfile -sastoken $sastoken }

    #create ingress kql file
    $csvfilename=(Get-ChildItem $csvfile).name #only csv filename

    # replace "-" "." "," with _ in table name
    $kustotable=$kustotable.replace("-","_")
    $kustotable=$kustotable.replace(".","_")
    $kustotable=$kustotable.replace(",","_")
    
    #generate SAS token and kql file
    $csvsas="$($sastoken.split('?')[0])/$($csvfilename)?$($sastoken.split('?')[1])"  
    $kqlcsvblob0=".drop table $($kustotable)_temp"
    $kqlcsvblob1=".create table $($kustotable)_temp (framenumber:long,frametime:string,DeltaDisplayed:string,Source:string,Destination:string,ipid:string,Protocol:string,tcpseq:string,tcpack:string,Length:int,tcpsrcport:int,tcpdstport:int,udpsrcport:int,udpdstport:int,tcpackrtt:string,frameprotocol:string,Info:string,ethsrc:string,ethdst:string,SourceV6:string,DestinationV6:string,ipProtocol:string,dnsid:string,ipTTL:string,ipFlags:string,tcpFlags:string,tcpwindowsize:int,tcplength:int,espseq:string,espspi:string,mysqlcmd:string)"
    $kqlcsvblob2=".ingest into table $($kustotable)_temp (@""$($csvsas)"") with (format='tsv',ignoreFirstRecord=true)"

    if ($multithread)
    {
        #multithread mode, append all Kusto query in one $($jobid)_1_ingress.kql
        # KQL need be single thread to process as it will lock the table
        Write-UTCLog "  +++ ksql:$($jobid)_1_ingress.kql, appending($($kustotable)) from blob [$($csvfilename)]" -color "Green"
        $kqlcsvblob0|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append  
        $kqlcsvblob1|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append  
        $kqlcsvblob2|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append  
        ".set-or-append $($kustotable) <|&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "let IPToInt = (ip:string) {&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[0]) * 256 * 256 * 256 +&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[1]) * 256 * 256 +&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[2]) * 256 +&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[3])};&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "$($kustotable)_temp &"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend aa=tolong(replace_string(frametime,'.',''))/1000&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend TT=unixtime_microseconds_todatetime(aa)&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend SourceCA=tostring(split(Source,',')[countof(Source,',')])//return inner src ip addres&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend DestCA=tostring(split(Destination,',')[countof(Destination,',')])//return inner dest ip addres&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend SourcePA=tostring(split(Source,',')[countof(Source,',')-1])//return outer src ip addres&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend DestPA=tostring(split(Destination,',')[countof(Destination,',')-1])//return outer dest ip addres&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ipidinner=split(ipid,',')[countof(ipid,',')] //return inner ipid&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ipTTLInner=split(ipTTL,',')[countof(ipTTL,',')] //return inner ipTTL&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ethsrci=tostring(split(ethsrc,',')[countof(ethsrc,',')]) //return inner src eth.addr&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ethdsti=tostring(split(ethdst,',')[countof(ethdst,',')]) //return inner dest eth.addr&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ipProtocoli=tostring(split(ipProtocol,',')[countof(ipProtocol,',')]) //return inner ipProtocol &"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| project-away framenumber, frametime, DeltaDisplayed, aa&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend flowhash=case(&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "ipProtocoli=='6', hash(IPToInt(SourceCA)+IPToInt(DestCA))+hash(toint(tcpsrcport)*toint(tcpdstport)),&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "ipProtocoli=='17', hash(IPToInt(SourceCA)+IPToInt(DestCA))+hash(toint(udpsrcport)*toint(udpdstport)),&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "ipProtocoli=='1',hash(IPToInt(SourceCA)+IPToInt(DestCA)),0)&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_a=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(SourceV6,':')[6]))))&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_b=toint(strcat('0x',tostring(split(SourceV6,':')[6])))-ip_a*256&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_c=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(SourceV6,':')[7]))))&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_d=toint(strcat('0x',tostring(split(SourceV6,':')[7])))-ip_c*256&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend Sourcev4decode=strcat(tostring(ip_a),'.',tostring(ip_b),'.',tostring(ip_c),'.',tostring(ip_d))&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend Sourcev4decode=iff(Sourcev4decode == '...',SourceV6,Sourcev4decode)&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| project-away ip_a, ip_b, ip_c , ip_d&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_a=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(DestinationV6,':')[6]))))&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_b=toint(strcat('0x',tostring(split(DestinationV6,':')[6])))-ip_a*256&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_c=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(DestinationV6,':')[7]))))&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend ip_d=toint(strcat('0x',tostring(split(DestinationV6,':')[7])))-ip_c*256&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend Destv4decode=strcat(tostring(ip_a),'.',tostring(ip_b),'.',tostring(ip_c),'.',tostring(ip_d))&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| extend Destv4decode=iff(Destv4decode == '...',DestinationV6,Destv4decode)&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| project-away ip_a, ip_b, ip_c, ip_d&"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        "| project-reorder flowhash, TT, SourcePA, DestPA, SourceCA, DestCA, ethsrci, ethdsti, ipProtocoli, Protocol,ipidinner, ipTTLInner, tcpseq, tcpack, tcpackrtt,tcpFlags,Length, Info, tcpsrcport, tcpdstport, udpsrcport, udpdstport,dnsid,ipFlags,tcpwindowsize,tcplength,espseq,espspi,mysqlcmd"|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append 
        $kqlcsvblob0|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append  
    }
    else {
        #single thread mode, execute kusto for single thread complete the command 
        Write-UTCLog "  +++ ksql:$($jobid)_1_ingress.kql, appending($($kustotable)) from blob [$($csvfilename)]" -color "Green"
        $kqlcsvblob0|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        $kqlcsvblob1|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        $kqlcsvblob2|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        ".set-or-append $($kustotable) <|&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "let IPToInt = (ip:string) {&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[0]) * 256 * 256 * 256 +&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[1]) * 256 * 256 +&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[2]) * 256 +&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "    toint(split(ip, '.')[3])};&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "$($kustotable)_temp &"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend aa=tolong(replace_string(frametime,'.',''))/1000&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend TT=unixtime_microseconds_todatetime(aa)&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend SourceCA=tostring(split(Source,',')[countof(Source,',')])//return inner src ip addres&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend DestCA=tostring(split(Destination,',')[countof(Destination,',')])//return inner dest ip addres&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend SourcePA=tostring(split(Source,',')[countof(Source,',')-1])//return outer src ip addres&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend DestPA=tostring(split(Destination,',')[countof(Destination,',')-1])//return outer dest ip addres&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ipidinner=split(ipid,',')[countof(ipid,',')] //return inner ipid&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ipTTLInner=split(ipTTL,',')[countof(ipTTL,',')] //return inner ipTTL&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ethsrci=tostring(split(ethsrc,',')[countof(ethsrc,',')]) //return inner src eth.addr&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ethdsti=tostring(split(ethdst,',')[countof(ethdst,',')]) //return inner dest eth.addr&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ipProtocoli=tostring(split(ipProtocol,',')[countof(ipProtocol,',')]) //return inner ipProtocol &"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| project-away framenumber, frametime, DeltaDisplayed, aa&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend flowhash=case(&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "ipProtocoli=='6', hash(IPToInt(SourceCA)+IPToInt(DestCA))+hash(toint(tcpsrcport)*toint(tcpdstport)),&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "ipProtocoli=='17', hash(IPToInt(SourceCA)+IPToInt(DestCA))+hash(toint(udpsrcport)*toint(udpdstport)),&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "ipProtocoli=='1',hash(IPToInt(SourceCA)+IPToInt(DestCA)),0)&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_a=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(SourceV6,':')[6]))))&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_b=toint(strcat('0x',tostring(split(SourceV6,':')[6])))-ip_a*256&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_c=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(SourceV6,':')[7]))))&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_d=toint(strcat('0x',tostring(split(SourceV6,':')[7])))-ip_c*256&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend Sourcev4decode=strcat(tostring(ip_a),'.',tostring(ip_b),'.',tostring(ip_c),'.',tostring(ip_d))&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend Sourcev4decode=iff(Sourcev4decode == '...',SourceV6,Sourcev4decode)&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| project-away ip_a, ip_b, ip_c , ip_d&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_a=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(DestinationV6,':')[6]))))&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_b=toint(strcat('0x',tostring(split(DestinationV6,':')[6])))-ip_a*256&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_c=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(DestinationV6,':')[7]))))&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend ip_d=toint(strcat('0x',tostring(split(DestinationV6,':')[7])))-ip_c*256&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend Destv4decode=strcat(tostring(ip_a),'.',tostring(ip_b),'.',tostring(ip_c),'.',tostring(ip_d))&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| extend Destv4decode=iff(Destv4decode == '...',DestinationV6,Destv4decode)&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| project-away ip_a, ip_b, ip_c, ip_d&"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        "| project-reorder flowhash, TT, SourcePA, DestPA, SourceCA, DestCA, ethsrci, ethdsti, ipProtocoli, Protocol,ipidinner, ipTTLInner, tcpseq, tcpack, tcpackrtt, tcpFlags,Length, Info, tcpsrcport, tcpdstport, udpsrcport, udpdstport,dnsid,ipFlags,tcpwindowsize,tcplength,espseq,espspi,mysqlcmd"|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append 
        $kqlcsvblob0|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii -Append  
        if ($debug) {Write-UTCLog "  ++kql: $($kqlcsvblob)"  "cyan"}
        #execute kusto for single thread complete the command below for multiple thread 
        $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql"""
        if ($debug) {Write-UTCLog "  ++kqlcmd: $($kqlcmd)" "cyan"}
        Write-UTCLog "  +++ (Kusto.Cli) (ADX) ingress table:($($kustotable)) from blob [$($csvfilename)]" -color "Green"
        if ($debug) {Invoke-Expression  $kqlcmd} else {Invoke-Expression  $kqlcmd| Out-Null}
    }
}


function CSVtoKustoEmulator([string]$csvfile,[string]$kustoendpoint,[string]$kustotable,[string]$jobid,[switch]$multithread=$false)
{
    if ($debug) {Write-UTCLog " ++function:CSVtoKustoEmulator " "Cyan"}
    #create ingress kql file
    $csvfilename=(Get-ChildItem $csvfile).fullname  #fullname will include absolute path

    # replace "-" "." "," with _ in table name
    $kustotable=$kustotable.replace("-","_")
    $kustotable=$kustotable.replace(".","_")
    $kustotable=$kustotable.replace(",","_")

    #generate kql file
    $kqlcsv=".ingest into table $($kustotable) (@""$($csvfilename)"") with (format='tsv',ignoreFirstRecord=true)"
    
    if ($debug) {Write-UTCLog "  ++kql: $($kqlcsv)"  "cyan"}
    if ($multithread)
    {
        #multi-thread mode, append all Kusto query in one $($jobid)_1_ingress.kql
        # KQL need be single thread to process as it will lock the table
        Write-UTCLog "  +++ ksql:$($jobid)_1_ingress.kql, appending($($kustotable)) from csv [$($csvfilename)]" -color "Green"
        $kqlcsv|out-file "$($workingfolder)\$($jobid)_1_ingress.kql" -Encoding ascii -Append  
    }
    else {
        #single thread mode, execute kusto for single thread complete the command 
        $kqlcsv|out-file "$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql" -Encoding ascii #still create the single file for debug purpose
        if ($debug) {Write-UTCLog "  ++kql: $($kqlcsvblob)"  "cyan"}
        #execute kusto for single thread complete the command below for multiple thread 
        $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($workingfolder)\$($jobid)_1_$($(Get-ChildItem $csvfile).BaseName)_ingress.kql"""
        if ($debug) {Write-UTCLog "  ++kqlcmd: $($kqlcmd)" "cyan"}
        Write-UTCLog "  +++ (Kusto.Cli) (ADX) ingress table:($($kustotable)) from local csv file [$($csvfilename)]" -color "Green"
        if ($debug) {Invoke-Expression  $kqlcmd} else {Invoke-Expression  $kqlcmd| Out-Null}
    }
}


function pcap2kustocore([string]$pcapfile,[string]$csvfile,[string]$kustoendpoint,[string]$kustotable,[string]$sastoken,[switch]$multithread=$false,[string]$jobid) # this handle one file only
{
    if ($debug) {Write-UTCLog  " +function:pcap2kustocore '$($pcapfile)'  multithread: $($multithread) jobid : $($jobid)" "cyan" }
    
    #config capinfos 
    set-alias capinfos "c:\Program Files\Wireshark\capinfos.exe"
    $pcapacketcount=[int][regex]::Match(((capinfos $pcapfile)|Select-String "Number of Packets ="), '\d+').Value

    #determine $pcapfile packet count if this is > 1500000, we will split orginial file into multiple and once it is complete the orginial file will get removed. 
    if ($pcapacketcount -le 2000000)
    {
        if ($multithread)
        {
            pcap2csv -pcapfile $pcapfile -csvfile $csvfile -jobid $jobid -multithread
        }
        else
        {
            pcap2csv -pcapfile $pcapfile -csvfile $csvfile -jobid $jobid
        }

        if ([string]::IsNullOrEmpty($kustoendpoint))
        {
            #Write-UTCLog " +KustoEndpoint is not specified, only pcap2csv only" "Red"
            return
        }
        else {
            if ($kustoendpoint.contains("kusto.windows.net") -or $kustoendpoint.contains("kusto.chinacloudapi.cn") -or $kustoendpoint.contains("kusto.fabric.microsoft.com"))
            {
                if ([string]::IsNullOrEmpty($sastoken))
                {
                    Write-UTCLog " +$($kustoendpoint) is used, but SAS token is not specified, existing..." "Red"
                }
                else {
                       CSVtoKustoCluster -csvfile $csvfile -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid
                }
            }
            else {
                      CSVtoKustoEmulator -csvfile $csvfile -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid
               }
        }
    }
    else {
        # split pcap file into multiple pcap files. 
        Write-UTCLog " $($pcapfile) has more than 1.5M packets, spliting..." "Yellow"
        Set-Alias editcap "c:\Program Files\Wireshark\editcap.exe"
        $splitcmd="editcap -c 1500000 ""$($pcapfile)"" ""$(Split-Path -Parent -path $pcapfile)\$(Split-Path -Leaf -path $pcapfile)"""
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
            Write-UTCLog "  +++pcap2csv(split): $($k)/$($pcapfiles.count) - $($pcap) " "Yellow"
            pcap2csv -pcapfile $pcap -csvfile "$(Split-Path -Parent -path $csvfile)\$($pcap.basename).csv" -jobid $jobid
            if ([string]::IsNullOrEmpty($kustoendpoint))
            {
                #if ($debug) {Write-UTCLog " +KustoEndpoint is not specified, only pcap2csv only" "Red"}
            }
            else {
                if ($kustoendpoint.contains("kusto.windows.net") -or $kustoendpoint.contains("kusto.chinacloudapi.cn") -or $kustoendpoint.contains("kusto.fabric.microsoft.com"))
                {
                    if ([string]::IsNullOrEmpty($sastoken))
                    {
                        Write-UTCLog " +$($kustoendpoint) is used, but SAS token is not specified, existing..." "Red"
                    }
                    else {
                        CSVtoKustoCluster -csvfile "$(Split-Path -Parent -path $csvfile)\$($pcap.basename).csv" -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid
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
$jobid= New-Guid  #everyrun get one unquie guid for job

#If csvfolder folder does not exist, create it
if (-not (Test-path $csvfolder))
{
    Write-UTCLog "'$($csvfolder)' does not exsit! Creating" "Yellow"
    mkdir $csvfolder | Out-Null
}

#If workingfolder folder does not exist, create it
if (-not (Test-path $workingfolder))
{
    Write-UTCLog "'$($workingfolder)' does not exsit! Creating" "Yellow"
    mkdir $workingfolder | Out-Null
}

#If tshark does not exist, install it
if (-not (Test-Path $tsharkcli))
{
    Write-UTCLog "'$($tsharkcli)' wasn't found, download and install Wireshark 3.4.9" "red"
    # Download the Wireshark installer
    (New-Object System.Net.WebClient).DownloadFile("https://www.wireshark.org/download/win64/all-versions/Wireshark-win64-3.4.9.exe", "$($workingfolder)\wireshark.exe")

    # Install Wireshark silently
    $arguments = "/S /D=`"$($env:ProgramFiles)\Wireshark`""
    Start-Process -FilePath "$($workingfolder)\wireshark.exe" -ArgumentList $arguments -Wait

    # Clean up the temporary files
    Remove-Item -Path "$($workingfolder)\wireshark.exe"

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

# search for azcopy.exe in temp folder if found, use Set-Alilas to config azcopy alias
if ((Get-ChildItem "$($workingfolder)\azcopy.exe" -Recurse).count -ne 0)
{
    Set-Alias -Name azcopy -Value (Get-ChildItem "$($workingfolder)\azcopy.exe" -Recurse)[0].FullName -ErrorAction SilentlyContinue 
}

# Check if AzCopy is already installed
if (-not (Get-Command azcopy -ErrorAction SilentlyContinue)) {

    Write-UTCLog "  azcopy wasn't found, download & unzip azcopy" -color "Yellow"
    # Download the AzCopy executable
    (New-Object System.Net.WebClient).DownloadFile("https://aka.ms/downloadazcopy-v10-windows", "$($workingfolder)\azcopy.zip")
    
    # Extract the AzCopy executable
    Expand-Archive -Path "$($workingfolder)\azcopy.zip" -DestinationPath $workingfolder -Force

    # Clean up the temporary files
    Remove-Item -Path "$($workingfolder)\azcopy.zip"

    #config azcopy alias and we can use in current session
    Set-Alias -Name azcopy -Value (Get-ChildItem "$($workingfolder)\azcopy.exe" -Recurse)[0].FullName

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
            # generate creata table kql file
            $kqlnewtable0=".drop table $($kustotable)"
            $kqlnewtable0|out-file "$($workingfolder)\$($jobid)_0_createtable.kql" -Encoding ascii
            #$kqlnewtable1=".create table $($kustotable) (framenumber:long,frametime:string,DeltaDisplayed:string,Source:string,Destination:string,ipid:string,Protocol:string,tcpseq:string,tcpack:string,Length:int,tcpsrcport:int,tcpdstport:int,udpsrcport:int,udpdstport:int,tcpackrtt:string,frameprotocol:string,Info:string,ethsrc:string,ethdst:string,SourceV6:string,DestinationV6:string,ipProtocol:string,dnsid:string,ipTTL:string,ipFlags:string,tcpFlags:string,tcpwindowsize:int,espseq:string,mysqlcmd:string)"
            #$kqlnewtable1|out-file "$($workingfolder)\$($jobid)_0_createtable.kql" -Encoding ascii -Append
            $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($workingfolder)\$($jobid)_0_createtable.kql"""
            Write-UTCLog " (Kusto.Cli.exe) remove table if that exist $($kustotable) @ $($kustoendpoint)" -color "Green"
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
                Write-UTCLog " Assume table:$($kustotable) exist. The Ingress KQL may fail if table does not exist..." "Yellow"
            }
        }

    }
}

if (Test-Path $tracefolder)  #validate
{
	if ($tracefile.contains("*") -or $tracefile.contains("?")) {
            Write-UTCLog "Generate a list of $($tracefile) under $($tracefolder) ..."
            $pcapfilelist=(Get-ChildItem "$($tracefolder)\$($tracefile)")
            
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

                if ($multithread)
                {
                    # multi-thread to process pcap files, will need create break the steps by tshark , azcopy , kqlcli
                    #first step is tshark multithread to process pcap files 
                    # get the number of logical processors
                    # (Get-WmiObject -Class Win32_Processor).NumberOfLogicalProcessors# this is buggy on dual core system it will return array with 2 elements
                    # PS C:\> (Get-WmiObject -Class Win32_Processor).NumberOfLogicalProcessors
                    # 12
                    # 12
                    # PS C:\> (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
                    # 24

                    $cores=(Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
                    Write-UTCLog " Multi-thread mode, using $($cores) cores to process pcap files" "Yellow"
                    $t0=Get-Date
                    $j=1    
                    foreach ($pcapfile in $pcapfilelist)
                    {
                        #check how many tshark or editcap already started, if total count execed the number of cores, wait for 1 second until the threads count less than cores.                            
                        $tsharkcount=get-process|where-object {($_.name -eq "tshark") -or ($_.name -eq "editcap")}|measure-object|select-object -expandproperty count
                        while ($tsharkcount -ge $cores)
                        {
                            Write-UTCLog " tshark count: $($tsharkcount) , sleep 1 seconds " "Yellow"
                            start-sleep -s 1
                            $tsharkcount=get-process|where-object {($_.name -eq "tshark") -or ($_.name -eq "editcap")}|measure-object|select-object -expandproperty count
                        }
                        Write-UTCLog " tshark $($j)/$($pcapfilelist.count) (m): $($pcapfile.FullName) " "Green"
                        $csvfilename="$($pcapfile.basename).csv"
                        # call pcap2csv function in multithread mode
                        pcap2csv -pcapfile "$($pcapfile.FullName)" -csvfile "$($csvfolder)\$($csvfilename)" -jobid $jobid -multithread
                        $j++
                    }

                    # This code is designed to prevent a potential issue in multi-thread mode where the tshark process may not have started yet. To avoid initiating azcopy prematurely, we've incorporated a 10-second delay.
                    $t01=Get-Date
                    if ($(($t01-$t0).TotalSeconds) -le 5) 
                    {
                        Write-UTCLog "Less 5 seconds to complete multiple threads for tshark batch, wait 10 seconds to ensure tshark process was started" -color "Yellow"
                        Start-Sleep -Seconds 10
                    }

                    # Pulling count of the tshark process, if the count is not 0, we need wait until all tshark process exit.
                    $tsharkcount=get-process|where-object {($_.name -eq "tshark") -or ($_.name -eq "editcap")}|measure-object|select-object -expandproperty count
                    Write-UTCLog " tshark count: $($tsharkcount)  " "Yellow"

                    if ($tsharkcount -ge 1) #when multithread > 1, we need wait all threads job to be finished before processing azcopy and kqlcli. 
                    {
                        $tsharkcount=get-process|where-object {($_.name -eq "tshark") -or ($_.name -eq "editcap")}|measure-object|select-object -expandproperty count
                        #wait loop to hold execution of azcopy if the total count exceed thread count
                        while ($tsharkcount -gt 0)
                        {
                            Write-UTCLog "Wait for tshark processes exit, sleep 1 second. (count: $tsharkcount)" -color "gray"
                            Start-Sleep -Seconds 1
                            $tsharkcount=get-process|where-object {($_.name -eq "tshark") -or ($_.name -eq "editcap")}|measure-object|select-object -expandproperty count
                        }
                    }
                    $t1=Get-Date
                    Write-UTCLog "[tshark pcap2csv :   $(($t1-$t0).TotalSeconds) secs, $(($t1-$t0).TotalMinutes) mins]" "Cyan"
                    Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"
                    #only SASTOKEN is not empy we can process azcopy
                    if ([string]::IsNullOrEmpty($sastoken)) 
                    {
                        #  when both $kustoendpoint and $kustotable has value and with domain suffix, we cannot processed without sastoken
                        if ($kustoendpoint.contains("kusto.windows.net") -or $kustoendpoint.contains("kusto.chinacloudapi.cn") -or $kustoendpoint.contains("kusto.fabric.microsoft.com"))
                        {
                            Write-UTCLog " SAS token is not specified, exit..." "Red"
                            exit
                        }
                        else {
                            if ((-not [string]::IsNullOrEmpty($kustoendpoint)) -and (-not [string]::IsNullOrEmpty($kustotable))) 
                            {
                                #step 3.1 is calling CSVtoKustoEmulator -multithread to generate one kql file for kqlcli to process, local mode
                                # create one kql file for all ingress command 
                                foreach ($pcapfile in $pcapfilelist)
                                {
                                    $csvfilename="$($pcapfile.basename).csv"
                                    # call CSVtoKustoEmulator function -multithread
                                    CSVtoKustoEmulator -csvfile "$($csvfolder)\$($csvfilename)" -kustoendpoint $kustoendpoint -kustotable $kustotable -jobid $jobid -multithread
                                }

                                # step 3.2 
                                $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($workingfolder)\$($jobid)_1_ingress.kql"""
                                Write-UTCLog " Excecute kqlcmd: $($kqlcmd)" "Yellow"
                                $time=((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")
                                Write-UTCLog " Please be patience , this might take a while for importing, To debug progress, you can use kusto query below " "Yellow"
                                Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"    
                                Write-Host " .show commands | where StartedOn > datetime('$($time)')|where CommandType in ('DataIngestPull','TableSetOrAppend')|order by StartedOn asc|extend Delta_in_ms=toreal(datetime_diff('nanosecond',StartedOn, prev(StartedOn)))/1000000 | project StartedOn, Delta_in_ms, CommandType, State, User, FailureReason, Text" -ForegroundColor "Gray"
                                Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"
                                if ($debug) {Invoke-Expression  $kqlcmd} else {Invoke-Expression  $kqlcmd| Out-Null}
                            }
                            else {
                                # exit here as not kusto endpoint specified, will exit after pcap2csv
                                Write-UTCLog " + KustoEndpoint KustoTable is empty, exit..." "Red"
                                exit
                            }

                            # calcuate how much time the program spent
                            $t3=Get-Date
                            Write-UTCLog "[ingress kusto local : $(($t3-$t1).TotalSeconds) secs, $(($t3-$t1).TotalMinutes) mins]" "Cyan"
                            Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"                        
                            Write-UTCLog "[pcap2kusto (MultiThread) - Local :   $(($t3-$t0).TotalSeconds) secs, $(($t3-$t0).TotalMinutes) mins]" "Cyan"                            
                        }
                    }
                    else {
                        #second step is azcopy multithread to process csv files
                        $j=1    
                        foreach ($pcapfile in $pcapfilelist)
                        {
                            #check how many tshark or editcap already started, if total count execed the number of cores, wait for 1 second until the threads count less than cores.                            
                            $azcopy=get-process|where-object {$_.name -eq "azcopy"}|measure-object|select-object -expandproperty count
                            while ($azcopy -ge $cores*5)  #user Core * 5 as max thread count
                            {
                                Write-UTCLog " azcopy count: $($azcopy) , sleep 1 second " "Yellow"
                                start-sleep -Seconds 1
                                $azcopy=get-process|where-object {$_.name -eq "azcopy"}|measure-object|select-object -expandproperty count
                            }
                            Write-UTCLog " azcopy $($j)/$($pcapfilelist.count) (m): $($pcapfile.FullName) " "Green"
                            $csvfilename="$($pcapfile.basename).csv"
                            # call CSVtoContainer function in multithread mode
                            CSVtoContainer -csvfile "$($csvfolder)\$($csvfilename)" -sastoken $sastoken -multithread
                            $j++
                        }

                        # This code is designed to prevent a potential issue in multi-thread mode where the azcopy process may not have started yet. To avoid initiating kusto import prematurely, we've incorporated a 10-second delay.
                        $t11=Get-Date
                        if ($(($t11-$t1).TotalSeconds) -le 5) 
                        {
                            Write-UTCLog "Less 5 seconds to complete multiple threads for tshark batch, wait 10 seconds to ensure tshark process was started" -color "Yellow"
                            Start-Sleep -Seconds 10
                        }
                        
                        #multi-thread azcopy cleanup 
                        $azcopy=get-process|where-object {$_.name -eq "azcopy"}|measure-object|select-object -expandproperty count

                        if ($azcopy -ge 1) #when multithread > 1, we need wait all threads job to be finished before processing kqlcli. 
                        {
                            $azcopy=get-process|where-object {$_.name -eq "azcopy"}|measure-object|select-object -expandproperty count
                            #wait loop to hold execution of kqlcli if the total count exceed thread count
                            while ($azcopy -gt 0)
                            {
                                Write-UTCLog "Wait for azcopy processes exit, sleep 1 second. (count: $azcopy)" -color "gray"
                                Start-Sleep -Seconds 1
                                $azcopy=get-process|where-object {$_.name -eq "azcopy"}|measure-object|select-object -expandproperty count
                            }
                        }
                        $t2=Get-Date
                        Write-UTCLog "[Azcopy csv2blob :   $(($t2-$t1).TotalSeconds) secs, $(($t2-$t1).TotalMinutes) mins]" "Cyan"
                        Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"
                        # if kustoendpoint is not empty, we can process kqlcli
                        if ([string]::IsNullOrEmpty($kustoendpoint) -and [string]::IsNullOrEmpty($kustotable)) 
                        {
                            Write-UTCLog " + KustoEndpoint or KustoTable is empty, exit..." "Red"
                            exit
                        }
                        else {
                            #step 3.1 is calling CSVtoKustoCluster -multithread to generate one kql file for kqlcli to process, cluster mode
                            # create one kql file for all ingress command 
                            foreach ($pcapfile in $pcapfilelist)
                            {
                                $csvfilename="$($pcapfile.basename).csv"
                                #Write-UTCLog " Ingress ADX(Kusto) $($j)/$($pcapfilelist.count) (m): $($csvfilename)" "Green"
                                # call CSVtoKusto function in multithread mode
                                if ($kustoendpoint.contains("kusto.windows.net") -or $kustoendpoint.contains("kusto.chinacloudapi.cn") -or $kustoendpoint.contains("kusto.fabric.microsoft.com"))
                                {
                                    CSVtoKustoCluster -csvfile "$($csvfolder)\$($csvfilename)" -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid -multithread
                                }
                                else {
                                    # We should never hit this code as if we specific sastoken we should alwayse use cluster mode instead of local mode. just in case we hit this , we will not fail. 
                                    CSVtoKustoEmulator -csvfile "$($csvfolder)\$($csvfilename)" -kustoendpoint $kustoendpoint -kustotable $kustotable -jobid $jobid -multithread
                                }
                            }

                            # step 3.2
                            $kqlcmd="$($kustocli) ""$kustoendpoint"" -script:""$($workingfolder)\$($jobid)_1_ingress.kql"""
                            Write-UTCLog " Excecute kqlcmd: $($kqlcmd)" "Yellow"
                            $time=((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss.fff")
                            Write-UTCLog " Please be patience , this might take a while for importing, To debug progress, you can use kusto query below " "Yellow"
                            Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"    
                            Write-Host " .show commands | where StartedOn > datetime('$($time)')| where CommandType == 'DataIngestPull'| project StartedOn, CommandType, State, User, FailureReason, Text " -ForegroundColor "Gray"
                            Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"
                            if ($debug) {Invoke-Expression  $kqlcmd} else {Invoke-Expression  $kqlcmd| Out-Null}
                        }
                        
                        # calcuate how much time the program spent
                        $t3=Get-Date
                        Write-UTCLog "[Ingress blob2kusto : $(($t3-$t2).TotalSeconds) secs, $(($t3-$t2).TotalMinutes) mins]" "Cyan"
                        Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"                        
                        Write-UTCLog "[pcap2kusto (MultiThread) - ADX :   $(($t3-$t0).TotalSeconds) secs, $(($t3-$t0).TotalMinutes) mins]" "Cyan"
                    }
                }
                else {
                    # single thread to process pcap files
                    $t0=Get-Date
                    $j=1  #fileindex for loop
                    foreach ($pcapfile in $pcapfilelist)
                    {
                        Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor "Gray"
                        Write-UTCLog " Processing $($j)/$($pcapfilelist.count) (s): $($pcapfile.FullName) " "Green"
                        $csvfilename="$($pcapfile.basename).csv"
                        pcap2kustocore -pcapfile "$($pcapfile.FullName)" -csvfile "$($csvfolder)\$($csvfilename)" -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid
                        $j++
                    }
                    # calcuate how much time the program spent
                    $t1=Get-Date
                    Write-UTCLog "[pcap2kusto (SingleThread) :   $(($t1-$t0).TotalSeconds) secs, $(($t1-$t0).TotalMinutes) mins]" "Cyan"
                }
            }
            else {
                Write-UTCLog " Pcap $($tracefile)\$($tracefile) Total : $($pcapfilelist.count) File(s) , exiting... " "Red"
            }        
        }
    else {
        if (Test-Path "$($tracefolder)\$($tracefile)")
        {
            $t0=Get-Date
            $pcapfile=Get-ChildItem "$($tracefolder)\$($tracefile)"
            $csvfilename="$($pcapfile.basename).csv"
            Write-UTCLog " Pcap File : 1, File Size : $($pcapfile.Length)bytes ($("{0:F2}" -f $($pcapfile.Length/1024/1024)) MBs), Required Disk Space (Estimate): $("{0:F2}" -f $($pcapfile.Length/1024/1024*2.40)) MBs " "Yellow"
            Write-UTCLog "$($pcapfile),$($pcapfile.Length)"
            pcap2kustocore -pcapfile "$($tracefolder)\$($tracefile)" -csvfile "$($csvfolder)\$($csvfilename)" -kustoendpoint $kustoendpoint -kustotable $kustotable -sastoken $sastoken -jobid $jobid

            # calcuate how much time the program spent
            $t1=Get-Date
            Write-UTCLog "[pcap2kusto (SingleThread-SingleFile) :   $(($t1-$t0).TotalSeconds) secs, $(($t1-$t0).TotalMinutes) mins]" "Cyan"

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