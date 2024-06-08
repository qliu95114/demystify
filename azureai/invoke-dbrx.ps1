Param(
    [string] $content = "What to eat today",
    [string] $contentFile,
    [string] $imageFile,
    [string] $prompt,
    [ValidateSet("common_create_prompt", "common_echo_text", "common_polish_text", "common_response_default", "common_summarize_text", "common_translate_to_en-us", "common_translate_to_zh-cn", "common_write_marketingcontent", "devops_beauty_json", "devops_explain_code", "devops_kustokql_samplecode", "devops_powershell_samplecode", "devops_python_samplecode", "support_AAD_copilot", "support_sumary_notes", "support_ta_case_skill_label", "support_update_casenotes", "support_write_casesummary", "support_write_initialresponse")][string]$promptchoice = "common_response_default",
    [string] $promptLibraryFile,
    [string] $promptFile,
    [string] $completionFile,
    [single] $temperature = 0.7,
    [switch] $DonotUpdateLastConfig,
    [switch] $debug
)

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. $scriptDir\utils.ps1
. $scriptDir\dbrx.ps1

# Global initialization
$prompturl = "https://raw.githubusercontent.com/qliu95114/demystify/main/azureai/prompt.json"

# Use $promptFile to overwrite the default prompt.json
# Use local prompt library file if specified
# Switch to default $env:USERPROFILE\.azureai\prompt.json if not specified
# All failed, download from github

# build out the prompt text
# primary choice -prompt
# secondary choice -promptFile
# third choice -promptchoice
if (![string]::IsNullOrEmpty($prompt)) {
    $promptText = $prompt
    Write-UTCLog "Prompt(Custom): $promptText" -color "DarkCyan"
}
else {
    if ($promptFile) {
        if (Test-Path $promptFile) {
            # if promptFile is specified and exists
            $promptText = Get-Content $promptFile -Raw
            Write-UTCLog "PromptFile system, use prompt from custom file: $promptFile" -color "DarkCyan"
            $promptforlogging = "PromptFile: $($promptFile)"
        }
        else {
            Write-UTCLog "PromptFiles ($($promptFile)) does not exist, please check" -color "red"
            exit
        }
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
            $localPromptLibraryFile = "$($env:USERPROFILE)\.azureai\prompt.json"
            if (Test-Path "$($env:USERPROFILE)\.azureai\prompt.json") {
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
        $promptText = ($promptLibraryJson | Where-Object { $_.'name' -eq $promptchoice }).prompt
        $promptforlogging = "PromptChoice: $($promptchoice)"
        if ($debug) { Write-Host $promptText -ForegroundColor "DarkCyan" }
        if ([string]::IsNullOrEmpty($promptText)) {
            $promptText = "You are an AI assistant that helps people find information."
        }
    }
}

if ([string]::IsNullOrEmpty($prompt) -and [string]::IsNullOrEmpty($promptFile)) {
    Write-UTCLog "PromptChoice  : $($promptchoice)" -color "DarkCyan"
    if ($debug) {
        $prompttext = $promptText.replace("\r\n", [System.Environment]::NewLine)  #replace \r\n
        Write-UTCLog "Prompt(system): $($prompttext)" -color "DarkCyan"
    }
}

# Check if contentFile is specified and exists
if ($contentFile -and (Test-Path $contentFile)) {
    $content = Get-Content $contentFile -Raw
}

# if content is too long, only print first 100 characters
if ($content.length -ge 100) { $offset = 100 } else { $offset = $content.length }
Write-UTCLog "Content(user) : $($content.Substring(0,$offset)) ..." -color "Yellow"
Write-UTCLog "Content(user) : Total characters number is $($content.Length)" -color "Yellow"

$t0 = Get-Date
$chat = Invoke-DBRXCompletion -Prompt $promptText -Message $content -Temperature $temperature

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
$delta = "{0:N2}" -f ((Get-Date) - $t0).TotalSeconds

# print out the result
Write-UTCLog "AI thinking time: $($delta) seconds" -color "Cyan"

# Unix Epoch time to UTC time
$unixEpoch = [datetime]'1/1/1970 00:00:00Z'
$dateTime = $unixEpoch.AddSeconds($chat.created).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

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
