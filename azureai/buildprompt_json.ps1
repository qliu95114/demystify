# this file consolidate *.md file into a single json file
# *.md file locate in currentfolder\prompt_library
# default output file is $env:temp\prompt_library.json
# json file schema 
# name : file name without extension
# role : system
# prompt : markdown file content, replace new line with \n , " with \n 

Param(
    [switch]$updategpt
)

#logging
Function Write-UTCLog ([string]$message, [string]$color = "white") {
    $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    $logstamp = "[" + $logdate + "]," + $message
    Write-Host $logstamp -ForegroundColor $color
}


# get current folder
$currentFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition

# get prompt_library folder
$promptLibraryFolder = Join-Path $currentFolder "prompt_library"

# get all markdown file
$markdownFiles = Get-ChildItem -Path $promptLibraryFolder -Filter *.md

# get output file
$outputFile = Join-Path $env:temp "prompt.json"

# create output file
New-Item -Path $outputFile -ItemType File -Force | Out-Null

# create json object
$jsonObject = @()

# loop through all markdown file
foreach ($markdownFile in $markdownFiles) {
    # get file name without extension
    $fileName = $markdownFile.BaseName

    # get file content in RAW format
    $fileContent = Get-Content -Path $markdownFile.FullName -Raw

    # replace new line with \n
    $fileContent = $fileContent -replace [System.Environment]::NewLine, "\r\n"

    # replace " with \n
    $fileContent = $fileContent -replace '"', '\"'

    # create json object
    $prompt = New-Object PSObject
    $prompt| Add-Member -MemberType NoteProperty -Name name -Value $fileName
    $prompt| Add-Member -MemberType NoteProperty -Name prompt -Value $fileContent
    $prompt| Add-Member -MemberType NoteProperty -Name role -Value "system"

    #Add the object to $jsonObject
    $jsonObject += $prompt
}

# write json object to output file
$jsonObject| ConvertTo-Json | Out-File -FilePath $outputFile -Encoding utf8 -Force

# write output file path to console
Write-UTCLog "output file path: $($outputFile)" -color "Cyan"

# if updategpt is true and invoke-azureai-gpt.ps1 exist in the same folder, update invoke-azureai-gpt.ps1 parameter validate set


if ($updategpt -and (Test-Path -Path (Join-Path $currentFolder "invoke-azureai-gpt.ps1"))) {
    
    $list=""""+($jsonObject.name -join ',').replace(",",""",""")+""""
    Write-UTCLog "list: $list" -color "Cyan"
    
    # find the line in invoke-azureai-gpt.ps1 that include "[ValidateSet(*any text*)" and replace the content with $list
    $invokeAzureAIGPTFile = Join-Path $currentFolder "invoke-azureai-gpt.ps1"
    $invokeAzureAIGPTFileContent = Get-Content -Path $invokeAzureAIGPTFile 
    $invokeAzureAIGPTFileContent = $invokeAzureAIGPTFileContent -replace "\[ValidateSet\(.*?\)\]","[ValidateSet($($list))]"
    $invokeAzureAIGPTFileContent | Out-File -FilePath $invokeAzureAIGPTFile -Encoding utf8 -Force
    Write-UTCLog "update invoke-azureai-gpt.ps1 parameter validate set" -color "Cyan"
}








