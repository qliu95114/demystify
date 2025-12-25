# Offline Analysis of Azure VNET Flow Logs Using Kusto

## Introduction

This guide provides a detailed walkthrough on processing Azure Virtual Network (VNet) flow logs offline, without relying on Microsoft's Traffic Analytics or Log Analytic Workspace. It includes a demo script to convert the `PT1H.json` file into JSON Array format and KQL command of data ingression.

## Prerequisites

- **Azure Account**:
  - If you have a public URL to offer the JSON file via a download link, an Azure subscription is not required. Otherwise, you’ll need an Azure subscription to create a storage account.
  - If using a local Kusto emulator, no Azure subscription is needed.
- **Blob Storage Account**: 
  - Access to the Azure Blob Storage where flow logs are stored.
  - If using a local Kusto emulator, no Azure subscription is needed.
- **Azure Data Explorer Cluster**:
  - Set up an Azure Data Explorer cluster or use the online [Kusto free offer](https://aka.ms/kustofree) 
  - Self-host Option use the [Kusto emulator](https://learn.microsoft.com/en-us/azure/data-explorer/kusto-emulator-overview).
- **Kusto Query Language (KQL)**: Basic understanding of KQL for writing queries.

## `PT1H.JSON` Header Issue

The `PT1H.json` file has a leading JSON header `{"records":` and a trailing `}` in a single line. No `\n\r` in the file. that causes common JSON parsers to treat it as a single JSON object. However, the actual payload is an array `[]` after the `"records"` header. This can be headache issues when deserializing the JSON object, especially for very large PT1H file (e.g., hundreds of MB). While Azure Native Log Analytics handles this seamlessly, offline processing requires manual intervention or other Non-Microsoft solution may not be able to handle that efficiency.

## Detailed Steps ( if you need process multiple files from vnetflowlog storage account, please use [flowlog_process powershell](/network/flowlog/flowlog_process.ps1))

1. **Download PT1H.json File**: Obtain the `PT1H.json` file from your Azure Blob Storage.
2. **Remove the JSON Header Using the Script**: a sample code snip are provided to remove the header and trailing. 
    ```powershell
    ## filename: json_header_remove.ps1
    ## 
    $inputFilePath = 'd:\temp\vnet_PT1H.json'

    # Define the path for the output file
    $outputFilePath = 'd:\temp\vnet_PT1H_array.json'

    # Read the content of the file
    $content = Get-Content -Path $inputFilePath -Raw
    # Check if content starts with '{"records":' and ends with '}'
    if ($content.StartsWith('{"records":') -and $content.EndsWith('}')) {
        # Remove the first '{"records":' and the last '}'
        # Calculate the length to remove
        $startRemoveLength = '{"records":'.Length
        $endRemoveLength = 1 # The length of '}'

        # Trim the content
        $trimmedContent = $content.Substring($startRemoveLength, $content.Length - $startRemoveLength - $endRemoveLength)

        # Output the trimmed content to a new file
        Set-Content -Path $outputFilePath -Value $trimmedContent

        Write-Host "Processing complete. The trimmed content has been saved to $outputFilePath"
    } else {
        Write-Host "The file content does not start with '{\"records\":' and/or end with '}'. No changes made."
    }
    ```
3. **Copy `vnet_PT1H_array.json` to Storage Account**: Use [Azure Storage Explorer](http://aka.ms/storageexplorer) or AzCopy to upload the file to your Azure Blob Storage.
4. **Create Kusto Table**:
    ```kql
    .create table vnetflowlog (timestamp:datetime,flowLogVersion:int,flowLogGUID:guid,macAddress:string,category:string,flowLogResourceID:string,targetResourceID:string,operationName:string,flowRecords:dynamic)
    ```
5. **Create JSON Ingestion Mapping**:
    ```kql
    .create table vnetflowlog ingestion json mapping 'vnetflowlogmapping' '[{"column":"timestamp","Properties":{"path":"$.time"}},{"column":"flowLogVersion","Properties":{"path":"$.flowLogVersion"}},{"column":"flowLogGUID","Properties":{"path":"$.flowLogGUID"}},{"column":"macAddress","Properties":{"path":"$.macAddress"}},{"column":"category","Properties":{"path":"$.category"}},{"column":"flowLogResourceID","Properties":{"path":"$.flowLogResourceID"}},{"column":"targetResourceID","Properties":{"path":"$.targetResourceID"}},{"column":"operationName","Properties":{"path":"$.operationName"}},{"column":"flowRecords","Properties":{"path":"$.flowRecords"}}]'
    ```
6. **Ingest the Array Version of `PT1H.json` into Kusto**:
    ```kql
    .ingest into table vnetflowlog ('<replace your own URL>/vnet_PT1H_array.json') with '{"format":"multijson", "ingestionMappingReference":"vnetflowlogmapping"}'
    ```
7. **Verify the Result**:
    ```kql
    vnetflowlog | project timestamp, flowRecords, fl=strlen(tostring(flowRecords)), macAddress, flowLogGUID
    ```
    
    Get total json array count via powershell 
    ```powershell 
    D:\temp> $j=Get-Content .\vnet_PT1H_array.json | ConvertFrom-Json
    D:\temp> $j.count
    15649
    ```
    Confirm we have same result in kusto table `vnetflowlog`
    ```kql
    vnetflowlog | summarize count() 
    ```
    |count_|
    |-|
    |15649|

8. **Expand the flow log in one line one entry format**
   ```kql
    vnetflowlog
    | mv-expand flows      = flowRecords.flows
    | mv-expand flowGroups = flows.flowGroups
    | mv-expand flowTuples = flowGroups.flowTuples
    | project flowTuples
    ```
9.  **(Optional) Create the flowTuplesTable_temp table to reduce query costs for deeper flow analysis.**
     ```kql
    .set-or-append flowTuplesTable_temp <|vnetflowlog
    | mv-expand flows      = flowRecords.flows
    | mv-expand flowGroups = flows.flowGroups
    | mv-expand flowTuples = flowGroups.flowTuples
    | project flowTuples
    ```

