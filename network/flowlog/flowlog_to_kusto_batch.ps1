<#
# Flow Log Processor for Azure Kusto (KQL)

## Overview
This PowerShell script automates the ingestion of Azure Network Flow Logs (JSON format) into a Kusto (Azure Data Explorer) database. It processes flow log files, generates KQL scripts dynamically, and executes them using the Kusto CLI to:
1. Create a temporary table with the appropriate schema
2. Ingest JSON flow log data
3. Transform and append the data to a target table (`flowTuplesTable`)

## Prerequisites
- **Kusto CLI (`Kusto.Cli.exe`)** - Required for executing KQL commands.
- **Azure Storage Account** - Flow logs must be stored in a publicly accessible container.
- **Kusto Cluster Access** - Valid connection string with appropriate permissions.

## Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `SourceFolder` | Path containing flow log JSON files. | `C:\FlowLogs\` |
| `DestinationFolder` | Directory for temporary KQL scripts. | `C:\Temp\KQLScripts\` |
| `KustoCliPath` | Path to `Kusto.Cli.exe`. Default: `D:\source_git\Script\KustoCLI\Kusto.Cli.exe` | |
| `KustoConnection` | Kusto cluster connection string (AAD authentication). | `"https://<cluster>.kusto.windows.net/<db>;AAD Federated Security=True"` |
| `FileNamePattern` | File filter for JSON flow logs. Default: `*.json` | |
| `storageurl` | Publicly accessible Azure Blob Storage URL (including container). | `"https://<storage>.blob.core.windows.net/<container>/"` |

## How It Works
1. **KQL Template**: Uses a predefined KQL template to:
   - Create/clear a temporary table (`vnetflowlog_temp`).
   - Define JSON ingestion mapping.
   - Ingest data from the specified blob URL.
   - Transform and append flow records to the target table.
2. **File Processing**:
   - Dynamically generates KQL scripts for each JSON file.
   - Executes scripts via Kusto CLI.
3. **Output**: Logs success/failure for each file.

## Usage Example
```powershell
.\ProcessFlowLogs.ps1 `
    -SourceFolder "C:\FlowLogs\" `
    -DestinationFolder "C:\Temp\KQLScripts\" `
    -KustoConnection "https://<cluster>.kusto.windows.net/<db>;AAD Federated Security=True" `
    -storageurl "https://<storage>.blob.core.windows.net/<container>/"
```

## Notes
- Ensure the storage container is **publicly readable** (or use SAS tokens if modifying the script).
- The script assumes the target table `flowTuplesTable` exists in the Kusto database.
- For large-scale processing, consider error handling and logging enhancements.

---
**Author**: Qing Liu
**Version**: 1.0
#>

param (
    [string]$SourceFolder,
    [string]$DestinationFolder,
    [string]$KustoCliPath="D:\source_git\Script\KustoCLI\Kusto.Cli.exe",
    [string]$KustoConnection, # sample "https://<kustoclustername>.kusto.windows.net/<dbname>;AAD Federated Security=True"
    [string]$FileNamePattern = "*.json", 
    [string]$storageurl # "https://<storageaccount>.blob.core.windows.net/<containername>/"
)

# KQL template with placeholders
$kqlTemplate = @"
.drop table vnetflowlog_temp

.create table vnetflowlog_temp (timestamp:datetime,flowLogVersion:int,flowLogGUID:guid,macAddress:string,category:string,flowLogResourceID:string,targetResourceID:string,operationName:string,flowRecords:dynamic)

.create table vnetflowlog_temp ingestion json mapping 'vnetflowlogmapping' '[{{"column":"timestamp","Properties":{{"path":"$.time"}}}},{{"column":"flowLogVersion","Properties":{{"path":"$.flowLogVersion"}}}},{{"column":"flowLogGUID","Properties":{{"path":"$.flowLogGUID"}}}},{{"column":"macAddress","Properties":{{"path":"$.macAddress"}}}},{{"column":"category","Properties":{{"path":"$.category"}}}},{{"column":"flowLogResourceID","Properties":{{"path":"$.flowLogResourceID"}}}},{{"column":"targetResourceID","Properties":{{"path":"$.targetResourceID"}}}},{{"column":"operationName","Properties":{{"path":"$.operationName"}}}},{{"column":"flowRecords","Properties":{{"path":"$.flowRecords"}}}}]'

.ingest into table vnetflowlog_temp ('"+$storageurl+"{0}') with '{{"format":"multijson", "ingestionMappingReference":"vnetflowlogmapping"}}'

.set-or-append flowTuplesTable <|vnetflowlog_temp &
| mv-expand flows      = flowRecords.flows &
| mv-expand flowGroups = flows.flowGroups &
| mv-expand flowTuples = flowGroups.flowTuples &
| project timestamp, macAddress, flowTuples &
| extend s=tostring(flowTuples) &
| extend parts  = split(s, ",") &
| extend ts_utc = unixtime_milliseconds_todatetime(tolong(parts[0])) &
| project &
    timestamp,macAddress,flowTuples, &
    timestamp_utc_str = todatetime(format_datetime(ts_utc, 'yyyy-MM-dd HH:mm:ss.fff')), &
    srcIP     = parts[1], &
    dstIP     = parts[2], &
    srcPort   = toint(parts[3]), &
    dstPort   = toint(parts[4]), &
    protocol  = toint(parts[5]), &
    direction = parts[6], &
    flow_state= parts[7], &
    flow_encryption = parts[8], &
    pkt_send   = tolong(parts[9]), &
    bytes_send     = tolong(parts[10]), &
    pkt_received   = tolong(parts[11]), &
    byte_received  = tolong(parts[12]) &
"@

# Create destination folder if it doesn't exist
if (-not (Test-Path -Path $DestinationFolder)) {
    New-Item -ItemType Directory -Path $DestinationFolder | Out-Null
}

# Get all JSON files matching the pattern
$jsonFiles = Get-ChildItem -Path $SourceFolder -Filter $FileNamePattern

foreach ($file in $jsonFiles) {
    Write-Host "Processing file: $($file.Name)"

    # Create temp KQL file name based on JSON file name (without extension)
    $tempKqlFile = Join-Path $DestinationFolder "temp_$($file.BaseName).kql"

    # Replace the filename in the template
    $kqlContent = $kqlTemplate -f $file.Name

    # Write the KQL content to temp file
    $kqlContent | Out-File -FilePath $tempKqlFile -Encoding utf8

    # Execute Kusto CLI
    try {
        & $KustoCliPath $KustoConnection -script:$tempKqlFile
        Write-Host "Successfully processed: $($file.Name)"
    }
    catch {
        Write-Error "Failed to process $($file.Name): $_"
    }
}

Write-Host "Processing completed."