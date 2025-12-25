

<# here is the sample process logic to remove header in a json file
1. Purpose

The purpose of this program is to recursively process a specific type of JSON file (PT1H.json) from a deeply nested, parameterized directory structure. The program will extract parameters from the folder names, apply a data transformation logic to each file, and save the results to a specified destination directory with a standardized, descriptive filename.

2. Inputs

root_path: The absolute path to the root of the source directory tree (e.g., C:\data\ROOT).
dest_path: The absolute path to the destination directory where processed files will be saved.

3. Source Folder Structure & Rules
The source directory tree is rigidly structured. Each level of the folder hierarchy is named with a key-value pair pattern, where the key is fixed and the value is a variable parameter.
Structure:​ root_path / y=<year> / m=<month> / d=<day> / h=<hour> / m=<minute> / macAddress=<address> / PT1H.json
Fixed Keys:​ y=, m=, d=, h=, m=, macAddress=.
Please be care ful we cannot change the folder structure and but generate the naming convention based on the folder structure. we need to follow the folder structure as is.
Variable Values:​ The segments after the =sign (e.g., 2025, 12, 22, 03, 00, 6045BDA9E154).

Target File:​ The only file to be processed is named PT1H.json, located in the final macAddress=directory. Any other files encountered should be silently skipped.

4. Processing Logic
For each PT1H.jsonfile found:
File Reading:​ The JSON content is read from the file.
Data Transformation:​ The existing, predefined data processing logic (referenced as "the process logic is already defined below" in the original request) is applied to the JSON data. The specifics of this logic (e.g., filtering, aggregation, reformatting) are to be implemented as per the pre-existing code.
Parameter Extraction:​ The parameters needed for the output filename (year, month, day, hour, minute, macAddress) are extracted from the folder path in which the file resides.

5. Output
Destination:​ Processed files are saved to the directory specified by dest_path.
Filename Convention:​ The output filename is generated dynamically using the extracted parameters, following this schema:
Format:​ flowlog_mac_<macAddress>_<year><month><day><hour><minute>_PT1H_array.json
Example:​ For a file found in the path .../y=2025/m=12/d=22/h=03/m=00/macAddress=6045BDA9E154/PT1H.json, the output filename will be:
flowlog_mac_6045BDA9E154_202512220300_PT1H_array.json

6. Core Requirements & Behavior
Recursive Traversal:​ The program must traverse the entire directory tree under root_path, including all subfolders at any depth.
Selective Processing:​ Only files explicitly named PT1H.jsonshould be processed. The program must ignore all other files and empty directories without error.
Error Handling:​ The program should be robust. It must gracefully handle and log (e.g., print a warning message) situations such as:
Invalid JSON file content.
Missing or unreadable files.
Permission errors.
A folder path that does not conform to the expected key=value structure (e.g., a folder named "archive" in the middle of the structure). The program should skip such branches.
Path Independence:​ The program should not make assumptions about the drive or top-level directory names above root_path. It should function based solely on the provided root_path.

7. Specification Summary
This specification defines a batch processing utility that automates the application of a data transformation routine to a large set of JSON files organized in a predictable folder hierarchy, producing timestamped and labeled output files in a consolidated location.
core processing logic is already defined below
#>

param (
    [string]$rootPath , ## The absolute path to the root of the source directory tree it must be acopy of the following blob storage account
    # \flowLogResourceID=\00000000-0000-0000-0000-000000000000_NETWORKWATCHERRG\NETWORKWATCHER_<REGION>_SUBNET-<YOUR_SUBNET>-FLOWLOG
    [string]$destPath ## local folder to store the processed files
)

function Process-File {
    param (
        [string]$filePath,
        [string]$outputFilePath
    )

    # Read the content of the file
    $content = Get-Content -Path $filePath -Raw
    # Check if content starts with '{"records":' and ends with '}'
    if ($content.StartsWith('{"records":') -and $content.EndsWith('}')) {
        # Remove the first '{"records":' and the last '}'
        $startRemoveLength = '{"records":'.Length
        $endRemoveLength = 1 # The length of '}'

        # Trim the content
        $trimmedContent = $content.Substring($startRemoveLength, $content.Length - $startRemoveLength - $endRemoveLength)

        # Output the trimmed content to a new file
        Set-Content -Path $outputFilePath -Value $trimmedContent

        Write-Host "Processed: $filePath -> $outputFilePath"
    } else {
        Write-Host "Skipped (Invalid Content): $filePath"
    }
}

function Process-Directory {
    param (
        [string]$rootPath,
        [string]$destPath
    )

    # Initialize counters
    $totalFiles = 0
    $processedFiles = 0
    $skippedFiles = 0

    # Get all PT1H.json files recursively
    Get-ChildItem -Path $rootPath -Filter "PT1H.json" -Recurse | ForEach-Object {
        $totalFiles++
        $filePath = $_.FullName

        # Extract parameters from the folder structure
        if ($filePath -match "y=(\d{4}).*m=(\d{2}).*d=(\d{2}).*h=(\d{2}).*m=(\d{2}).*macAddress=([A-Fa-f0-9]+)") {
            $year = $matches[1]
            $month = $matches[2]
            $day = $matches[3]
            $hour = $matches[4]
            $minute = $matches[5]
            $macAddress = $matches[6]

            # Generate output file name
            $outputFileName = "flowlog_mac_${macAddress}_${year}${month}${day}${hour}${minute}_PT1H_array.json"
            $outputFilePath = Join-Path -Path $destPath -ChildPath $outputFileName

            # write host for testing purpose
            Write-Host "Would process: $filePath -> $outputFilePath"
            # Process the file
            Process-File -filePath $filePath -outputFilePath $outputFilePath
            $processedFiles++
        } else {
            Write-Host "Skipped (Invalid Path Structure): $filePath"
            $skippedFiles++
        }
    Write-Host "Summary: Total=$totalFiles, Processed=$processedFiles, Skipped=$skippedFiles"
    }
}

Process-Directory -rootPath $rootPath -destPath $destPath

