<#
.SYNOPSIS
Merge & Covert NSG Flow log v2 PT1H.JSON under a folder to one single CSV file

.DESCRIPTION
Merge & Covert NSG Flow log v2 PT1H.JSON under a folder to one single CSV file, target CSV file will locate at the same as source folder

.PARAMETER srcpath
The source folder where NSGFLOWlogs PT1H.json are located. 

.EXAMPLE
.\convert-nsgflowlog2csv.ps1 -srcpath d:\temp 
#>

<#
author: qliu

.create table nsgflowlog (timestamp:datetime,macAddress:string,category:string,Version:string,rule:string,mac:string,epochtime:string,sourceip:string,destip:string,sourceport:int,destport:int,Protocol:string,TrafficFlow:string,TrafficDecision:string,FlowState:string,PacketsS2D:int,BytesSentS2D:int,PacketsD2S:int,BytesSentD2S:int)

.ingest into table nsgflowlog (@"D:\temp\nsgflowlogs_merge.csv") with (format='csv',ignoreFirstRecord=true)

#>

Param (
    [string]$srcpath="d:\temp"
)

Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

Function PT1H2CSV ([string]$srcpt1h,[string]$csvfile)  #FlatJSON 
{
    Write-UTCLog "processing... $($srcpt1h)"
    #Write-UTCLog "processing... $($csvfile)"
    $json=(Get-Content $srcpt1h)|ConvertFrom-Json
    foreach ($record in $json.records)
    {
        $line=""
        $time=$record.time
        #$systemId=$record.systemId
        $macAddress=$record.macAddress
        $category=$record.category
        #$resourceId=$record.resourceId
        #$operationName=$record.operationName
        foreach ($properties in $record.properties)
        {
            $version=$properties.Version
            foreach ($flow in $properties.flows)
            {
                $rule=$flow.rule
                #Write-UTCLog "[Debug]$($line)" -color "White"
                foreach ($flow2 in $flow.flows)
                {
                    $mac=$flow2.mac
                    #Write-UTCLog "[Debug]$($line)" -color "White"
                    foreach ($flowTuple in $flow2.flowTuples)
                    {
                        $Tuple=$flowTuple
                        #$line="$($time),$($systemId),$($macAddress),$($category),$($resourceId),$($operationName),$($version),$($rule),$($mac),$($Tuple)"
                        $line="$($time),$($macAddress),$($category),$($version),$($rule),$($mac),$($Tuple)"
                        $line|Out-File $csvfile -Encoding utf8 -Append
                    }
                }
            }
        }
    }
}


Function PT1H2CSV_Memory ([string]$srcpt1h,[string]$csvfile)  #FlatJSON Using Memory and Flush CSV 
{
    Write-UTCLog "processing... $($srcpt1h) in Memoory"
    #Write-UTCLog "processing... $($csvfile)"
    $json=(Get-Content $srcpt1h)|ConvertFrom-Json
    $flowtable = New-Object -TypeName 'System.Collections.ArrayList';
    foreach ($record in $json.records)
    {
        $line=""
        $time=$record.time
        #$systemId=$record.systemId
        $macAddress=$record.macAddress
        $category=$record.category
        #$resourceId=$record.resourceId
        #$operationName=$record.operationName
        foreach ($properties in $record.properties)
        {
            $version=$properties.Version
            foreach ($flow in $properties.flows)
            {
                $rule=$flow.rule
                #Write-UTCLog "[Debug]$($line)" -color "White"
                foreach ($flow2 in $flow.flows)
                {
                    $mac=$flow2.mac
                    #Write-UTCLog "[Debug]$($line)" -color "White"
                    foreach ($flowTuple in $flow2.flowTuples)
                    {
                        $Tuple=$flowTuple
                        #$line="$($time),$($systemId),$($macAddress),$($category),$($resourceId),$($operationName),$($version),$($rule),$($mac),$($Tuple)"
                        #$line="$($time),$($macAddress),$($category),$($version),$($rule),$($mac),$($Tuple)"
                        $flow = New-Object PSObject -Property @{
                            time = $time;
                            macAddress = $macAddress;
                            category = $category;
                            Version = $version;
                            rule = $rule;
                            mac = $mac;
                            epochtime = $Tuple.split(',')[0];
                            sourceip = $Tuple.split(',')[1];
                            destip = $Tuple.split(',')[2];
                            sourceport = $Tuple.split(',')[3];
                            destport = $Tuple.split(',')[4];
                            Protocol = $Tuple.split(',')[5];
                            TrafficFlow = $Tuple.split(',')[6];
                            TrafficDecision = $Tuple.split(',')[7];
                            FlowState = $Tuple.split(',')[8];
                            PacketsS2D = $Tuple.split(',')[9];
                            BytesSentS2D = $Tuple.split(',')[10];
                            PacketsD2S = $Tuple.split(',')[11];
                            BytesSentD2S = $Tuple.split(',')[12];
                        }
                        $flowtable+=$flow
                        #$line|Out-File $csvfile -Encoding utf8 -Append
                    }
                }
            }
        }
    }
    $flowtable.count
    $flowtable|Export-Csv $csvfile -Encoding utf8 -NoClobber
}

#get list of PT1h.Json
if (Test-Path $srcpath) 
{
    Write-UTCLog "Generate a list of nsgflowlogs (PT1H.JSON) under $($srcpath) ..."
    $nsgfilelist=(Get-ChildItem "$($srcpath)\PT1H.JSON" -Recurse)

    if ($nsgfilelist.count -ne 0)
    {
        $destfile="$($srcpath.TrimEnd('\'))\nsgflowlogs_merge.csv"
        #$destfile2="$($srcpath.TrimEnd('\'))\nsgflowlogs_merge_memory.csv"
        $header="time,macAddress,category,Version,rule,mac,epochtime,sourceip,destip,sourceport,destport,Protocol,TrafficFlow,TrafficDecision,FlowState,PacketsS2D,BytesSentS2D,PacketsD2S,BytesSentD2S"
        $header|Out-File $destfile -Encoding utf8
        #Write-UTCLog "nsgflowlogs Total : $($nsgfilelist.count) File(s)" "Yellow"
        [Int64]$totalsize=0
        foreach ($nsgfile in $nsgfilelist)
        {
            Write-UTCLog "$($nsgfile),$($nsgfile.Length)"
            $totalsize+=$nsgfile.Length
        }
        Write-UTCLog " nsgflowlogs Total : $($nsgfilelist.count) File(s) , total size : $($totalsize)" "Yellow"

        foreach ($nsgfile in $nsgfilelist)
        {
            PT1H2CSV -srcpt1h $nsgfile.FullName -csvfile $destfile
            #PT1H2CSV_Memory -srcpt1h $nsgfile.FullName -csvfile $destfile2
        }
        Write-UTCLog " nsgflowlogs CSV file : $($destfile)" "Yellow"
        
    }
    else {
        Write-UTCLog " nsgflowlogs Total : $($nsgfilelist.count) File(s) , existing... " "Red "
    }
} 
else {
    Write-UTCLog "$($srcpath) does not exsit, please check"  -color "Red"
}