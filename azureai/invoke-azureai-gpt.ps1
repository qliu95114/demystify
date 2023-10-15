<#
.SYNOPSIS
Work with AzureAI GPT-3.5 API.

.DESCRIPTION
This script is used to work with AzureAI GPT API, send content to AzureAI and get the response. 
Allow user to select different promptchoice from prompt.json to fine tune the response.
Allow user to use text file as large user prompt. 
Allow user to save the response to a completion file.
Allow user to specfic promptfile as system prompt instead of using default prompt.json & promptchoice.

.PARAMETER content
Content to be sent to AzureAI GPT-3.5 API

.PARAMETER promptchoice
promptchoice , that matches prompt.json file 

.PARAMETER contentFile
Path user prompt content file

.PARAMETER endpoint
AzureAI GPT-3.5 API endpoint, for example "https://<Azure AI Endpoint>.openai.azure.com/"

.PARAMETER DeploymentName
DeploymentName for AzureAI GPT-3.5 API

.PARAMETER apikey
apikey for AzureAI GPT-3.5 API

.PARAMETER aikey
GUID, Instrumentation Key used by Application Insight

.PARAMETER promptLibraryFile
Path to the local prompt.json file

.PARAMETER promptFile
Path to a file containing a custom system prompt to be used, if this is specified, promptchoice will be ignored

.PARAMETER completionFile
Path to a file to save the response from AzureAI GPT-3.5 API

.PARAMETER debug
render the output in debug mode

.EXAMPLE
Use Default template to ask GPT "what to eat today"
.\invoke-azureai-gpt.ps1 -content "What to eat today" 

.EXAMPLE
Use Translate to English template to ask GPT "what to eat today"
.\invoke-azureai-gpt.ps1 -content "What to eat today" -promptchoice "common_translate_to_zh-cn"

.EXAMPLE
Use Chinese to English template to ask GPT "what to eat today" and overwrite deployment in enviornment 
.\invoke-azureai-gpt.ps1 -content "What to eat today" -promptchoice "common_translate_to_zh-cn" -deploymentname "gpt3-5-2021-04-08-01"

.EXAMPLE
Specify a prompt file to as system prompt, -promptchoice & -promtlibrary will be ignored
.\invoke-azureai-gpt.ps1 -content "help me write a prompt file that create project plan" -promptFile ".\prompt_library\blairch\create_prompt.md" 

.EXAMPLE
Use local -promptlibrary file instead of downloading from github, avoid download issue. 
.\invoke-azureai-gpt.ps1 -content "help me write a prompt file that create project plan" -promptLibraryFile $env:temp\prompt.json -promptchoice "common_create_prompt" 

.EXAMPLE
output the response to a file
.\invoke-azureai-gpt.ps1 -content "help me write a prompt file that create project plan" -promptchoice "common_create_prompt" -completionFile $env:temp\completion.txt

.NOTES
Author: qliu
contributor: blairch
Date: 2023-08-13, first version
To use the invoke-azureai-gpt.ps1, please env_setup.cmd first to setup the environment variables 
SETX OPENAI_API_KEY_AZURE "<Input your API key here>"
SETX OPENAI_ENGINE_AZURE "<Input Deployment Name>"
SETX OPENAI_ENDPOINT_AZURE "https://<Azure AI Endpoint>.openai.azure.com/"

.LINK
Get code idea from below github repo
https://github.com/blrchen/azuredevops-pr-gpt
https://github.com/chenxizhang/openai-powershell


#>

# Parameter definition
Param(
    [string] $content = "What to eat today",
    [string] $contentFile,
    [string] $endpoint = $env:OPENAI_ENDPOINT_AZURE,
    [string] $DeploymentName = $env:OPENAI_ENGINE_AZURE,
    [string] $apikey = $env:OPENAI_API_KEY_AZURE,
    [ValidateSet("common_create_prompt","common_echo_text","common_polish_text","common_response_default","common_summarize_text","common_translate_to_en-us","common_translate_to_zh-cn","common_write_marketingcontent","devops_beauty_json","devops_explain_code","devops_kustokql_samplecode","devops_powershell_samplecode","devops_python_samplecode","support_AAD_copilot","support_sumary_notes","support_update_casenotes","support_write_casesummary","support_write_initialresponse")][string]$promptchoice="common_response_default",
    [string] $aikey,
    [string] $promptLibraryFile,
    [string] $promptFile,
    [string] $completionFile,
    [switch] $debug
)

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. $scriptDir\utils.ps1

# main program started

# downoad prompt.json from url blow # https://raw.githubusercontent.com/qliu95114/demystify/main/azureai/prompt.json
# $j=(get-content "$($env:temp)\prompt.json" -encoding utf8 )|convertfrom-json
# $c="";foreach ($i in $j.'name_en-us') {$c+="""$($i)"","} ; $c.trimend(鈥?")
# "Default","Text Polish","Chinese to English","English to Chinese","Code Re-Factory","Explain Code","Summarize Text","Echo","Powershell Sample Code","Python Sample Code","KQL ADX","Marketing Writing Assistant","JSON Format Assistant"

# global initialization
$scriptname = $MyInvocation.MyCommand.Name
$prompturl = "https://raw.githubusercontent.com/qliu95114/demystify/main/azureai/prompt.json"

# use $promptFile to overwrite the default prompt.json
# use localprompt library file if specified
# switch to default $env:temp\prompt.json if not specified
# all failed, download from github
if ($promptFile -and (Test-Path $promptFile)) {
    $prompt = Get-Content $promptFile -Raw
    Write-UTCLog "PromptFile system, use custom file: $promptFile" -color "DarkCyan" 
}
else { 
    # Check if promptLibraryFile is specified and exists
    if ($promptLibraryFile -and (Test-Path $promptLibraryFile)) {
        $localPromptLibraryFile = $promptLibraryFile
        Write-UTCLog "PromptLibrary (Custom): $localPromptLibraryFile" -color "white"
    }
    else {
        # if prompt.json already exist, skip download from github
        # If not, download the prompt.json from github
        $localPromptLibraryFile = "$($env:temp)\prompt.json"
        if (Test-Path "$($env:temp)\prompt.json"){
            Write-UTCLog "PromptLibrary (Cached): $localPromptLibraryFile" -color "Gray"
        }
        else {
            if ($debug) { Write-UTCLog "Downloading Prompt library $($prompturl)" -color "DarkCyan" }
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($promptUrl, $localPromptLibraryFile)
            Write-UTCLog "PromptLibrary (Github): $($prompturl)" -color "DarkCyan"
        }
    }

    # use $promptchoice to select the prompt from the json file
    $promptLibraryJson = Get-Content $localPromptLibraryFile -Encoding UTF8 | ConvertFrom-Json
    $prompt = ($promptLibraryJson | Where-Object { $_.'name' -eq $promptchoice}).prompt
    if ($debug) {Write-Host $prompt -ForegroundColor "DarkCyan"}
    if ([string]::IsNullOrEmpty($prompt)) {
        $prompt = "You are an AI assistant that helps people find information."
    }
}


# Check all parameters are set
if (!$endpoint -or !$DeploymentName -or !$apikey) { 
    Write-UTCLog "Endpoint, DeploymentName or apikey is not set, exit. Please use evn_setup.cmd to config endpoint/deployment/apikey" -color "Red"; 
    exit
}

Write-UTCLog "Endpoint      : $($endpoint)" -color "gray"
Write-UTCLog "Deployment    : $($DeploymentName)" -color "gray"
Write-UTCLog "PromptChoice  : $($promptchoice)" -color "Green"
if ($debug) {
    $prompttext=$prompt.replace("\r\n",[System.Environment]::NewLine)  #replace \r\n 
    Write-UTCLog "Prompt(system): $($prompttext)" -color "DarkCyan"
}

# Check if contentFile is specified and exists
if ($contentFile -and (Test-Path $contentFile)) {
    $content = Get-Content $contentFIle -Raw
    Write-UTCLog "Content(user) first 100: $($content.Substring(0,100))" "Yellow"
}
else {
    Write-UTCLog "Content(user) : $($content)" "Yellow"
}

$t0 = Get-Date
$chat = Invoke-ChartGPTCompletion -Endpoint $($endpoint) -AccessKey $($apikey) -DeploymentName $($DeploymentName) -Prompt $prompt -Message $content
$t1 = Get-Date
$suggestion = $chat.choices[0].message.content

if ($PSVersionTable['PSVersion'].Major -eq 5) {
    $dstEncoding = [System.Text.Encoding]::GetEncoding('iso-8859-1')
    $srcEncoding = [System.Text.Encoding]::UTF8
    $suggestion = $srcEncoding.GetString([System.Text.Encoding]::Convert($srcEncoding, $dstEncoding, $srcEncoding.GetBytes($chat.choices[0].message.content)))
}
else {
    $suggestion = $chat.choices[0].message.content
}

# Save the response to the file
if ($completionFile) {
    $suggestion | Out-File -FilePath $completionFile -Encoding utf8
    Write-UTCLog "Response saved to file: $completionFile" -color "DarkCyan"
}

# get delta time between $t1 and t0 in seconds and in format of xx.xx
$delta = "{0:N2}" -f ($t1 - $t0).TotalSeconds

# print out the result
Write-UTCLog "AI thinking time: $($delta) seconds"  -color "Cyan"

# Unix Epoch time to UTC time
$unixEpoch = [datetime]'1/1/1970 00:00:00Z'
$dateTime = $unixEpoch.AddSeconds($($chat.created)).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

# output the result properties
if ($debug) {
    Write-Host "---------------------------------------------------------" -ForegroundColor "DarkCyan"
    Write-Host "Id               : $($chat.id)" -ForegroundColor "gray"
    Write-Host "Object           : $($chat.object)" -ForegroundColor "gray"
    Write-Host "Model            : $($chat.model)" -ForegroundColor "gray"
    Write-Host "CreateTime       : $($dateTime)" -ForegroundColor "gray"
    Write-Host "Token_Completion : $($chat.usage.completion_tokens)" -ForegroundColor "gray"
    Write-Host "Token_Prompt     : $($chat.usage.prompt_tokens)" -ForegroundColor "gray"
    Write-Host "Token_Total      : $($chat.usage.total_tokens)" -ForegroundColor "gray"
}
Write-Host "---------------------------------------------------------" -ForegroundColor "Cyan"
Write-Host "$($suggestion)" -ForegroundColor "Cyan"
Write-Host "---------------------------------------------------------" -ForegroundColor "Cyan"

if ([string]::IsNullOrEmpty($aikey)) {
    if ($debug) { Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "DarkCyan" }
} 
else {
    if ($debug) { Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "DarkCyan" }

    #get hostname from $endpoint and retrieve the name before .openai.azure.com
    Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{DeploymentName = $DeploymentName.tostring(); chatid = $chat.id.tostring();
        object = $chat.object.tostring(); model = $chat.model.tostring(); CreatedTime = $datetime; token_completion = $chat.usage.completion_tokens;
        token_prompt = $chat.usage.prompt_tokens; token_total = $chat.usage.total_tokens; promptchoice = $promptchoice.tostring(); endpoint = $endpoint.split("/")[2].tostring()
    }
}
