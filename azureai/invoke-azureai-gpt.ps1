<#
.SYNOPSIS
Work with Azure OpenAI API via Powershell

.DESCRIPTION
This script is used to work with AzureAI GPT API, send content to AzureAI and get the response. 
Allow user to select different promptchoice from prompt.json to fine tune the response.
Allow user to use text file as large user prompt. 
Allow user to save the response to a completion file.
Allow user to specfic promptfile as system prompt instead of using default prompt.json & promptchoice.
Parameters are divided into four categories:

input (user prompt - only one of below two is required or needed）
    -content : [string] as user prompt string 
    -contentFile : [path to file] as user prompt string
input (system promt - only one of below three is required or needed）
    -prompt ： [string] as system prompt string   
    -promptchoice : [string] as promptchoice from prompt.json, （optional) -promptlibraryfile to overwrite default $($env:temp)\prompt.json
    -promptFile : [path to file] as prompt.md file
output (response)
    default output to console
    -completionFile : [path to file] as response from AzureAI GPT API
config (Azure OpenAI connection management)
    endpoint, deploymentname, apikey, token
    due to api parameter change in 1106 , add two parameters for model version 1106
    -maxtoken_input : [int] as max token for input
    -maxtoken_output : [int] as max token for output
    v2 configureation 
    -listconfig : dump the config parameters in $profile\.azureai\azureai_config.json
    -modelname : [string] as model name
    -modelversion : [string] as model version


.PARAMETER content
Content to be sent to Azure OpenAI GPT 

.PARAMETER contentFile
Path to user prompt content file

.PARAMETER prompt
Prompt , that will be used as system prompt

.PARAMETER promptchoice
promptchoice , that matches prompt.json file 

.PARAMETER promptLibraryFile
Path to the local prompt.json file

.PARAMETER promptFile
Path to a file containing a custom system prompt to be used, if this is specified, promptchoice will be ignored

.PARAMETER completionFile
Path to a file to save the response from Azure OpenAI  

.PARAMETER endpoint
Azure OpenAI endpoint, for example "https://<Azure AI Endpoint>.openai.azure.com/"

.PARAMETER DeploymentName
DeploymentName for Azure OpenAI 

.PARAMETER apikey
apikey for Azure OpenAI Endpint

.PARAMETER aikey
GUID, Instrumentation Key used by Application Insight

.PARAMETER token
Max token for AzureAI GPT-3.5/4 API 

.PARAMETER maxtoken_input
max token for input for AzureAI GPT-3.5/4 (1106 version)

.PARAMETER maxtoken_output
max token for output for AzureAI GPT-3.5/4 (1106 version)

.PARAMETER debug
render the output in debug mode

.PARAMETER listconfig
dump the config parameters in $profile\.azureai\azureai_config.json

.PARAMETER modelname
specify model name

.PARAMETER modelversion
specify version name

.PARAMETER DonotUpdateLastConfig
Do not update the last used configuration in $profile\.azureai\azureai_config_last.json

.EXAMPLE
Use ask gpt with prompt and content
.\invoke-azureai-gpt.ps1 -prompt "You are echo gpt, repeat everything received" -content "good morning"

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
To use the invoke-azureai-gpt.ps1, please env_setup.cmd first to setup the environment variables (Connection management v1)
SETX OPENAI_API_KEY_AZURE "<Input your API key here>"
SETX OPENAI_ENGINE_AZURE "<Input Deployment Name>"
SETX OPENAI_ENDPOINT_AZURE "https://<Azure AI Endpoint>.openai.azure.com/"
SETX OPENAI_TOKENS_AZURE "16384" or other value  # this is for max tokens we specific in GPT calls. when we call GPT, we need calcuate the remaining tokens we want to use.

.LINK
Get code idea from below github repo
https://github.com/blrchen/azuredevops-pr-gpt
https://github.com/chenxizhang/openai-powershell

#>

# Parameter definition
Param(
    [string] $content = "What to eat today",
    [string] $contentFile,
    [string] $prompt,
    [ValidateSet("common_create_prompt","common_echo_text","common_polish_text","common_response_default","common_summarize_text","common_translate_to_en-us","common_translate_to_zh-cn","common_write_marketingcontent","devops_beauty_json","devops_explain_code","devops_kustokql_samplecode","devops_powershell_samplecode","devops_python_samplecode","support_AAD_copilot","support_sumary_notes","support_ta_case_skill_label","support_update_casenotes","support_write_casesummary","support_write_initialresponse")][string]$promptchoice = "common_response_default",
    [string] $promptLibraryFile,
    [string] $promptFile,
    [string] $completionFile,
    [string] $endpoint = $env:OPENAI_ENDPOINT_AZURE,
    # To correct use the deployment name, please ensure you create deployment in azure openai portal first and use the exact name matches the model name
    [string] $DeploymentName = $env:OPENAI_ENGINE_AZURE,
    [string] $apikey = $env:OPENAI_API_KEY_AZURE,
    [string] $token = $env:OPENAI_TOKENS_AZURE,
    [single] $temperature = 0.7,
    [string] $maxtoken_output = $env:OPENAI_MAXTOKENSOUTPUT_AZURE,  # this is for max tokens we specific in supporting new api model GPT-4 or 3.5 1106 preview, the token limitation was change to Input : x and Output : 4096, instead of total token
    [string] $maxtoken_input = $env:OPENAI_MAXTOKENSINPUT_AZURE,  # this is for max tokens we specific in supporting new api model GPT-4 or 3.5 1106 preview, the token limitation was change to Input : x and Output : 4096, instead of total token
    [string] $aikey,
    [switch] $listconfig,
    [ValidateSet("gpt-35-turbo","gpt-35-turbo-16k","gpt-35-turbo-instruct","gpt-4","gpt-4-32k")][string] $modelname,
    [ValidateSet("1","001","2","0301","0314","0613","0914","1106","1106-Preview")][string] $modelversion,
    [switch] $DonotUpdateLastConfig,
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

# if listconfig is specified, dump the config parameters in $($env:USERPROFILE)\.azureai\azureai_config.json
if ($listconfig) 
{ 
    # dump the config parameters in $profile\.azureai\azureai-config.json
    if (Test-path "$($env:USERPROFILE)\.azureai\azureai-config.json")
    {
        Write-UTCLog "Dump $($env:USERPROFILE)\.azureai\azureai-config.json, you can append the parameter sample" -color "Cyan" 
        $openai_configs=(get-content "$($env:USERPROFILE)\.azureai\azureai-config.json")|convertfrom-json
        foreach ($config in $openai_configs)
        {
            $endpoint = "https://$($config.Id.split("/")[8]).openai.azure.com/"
            $Deployment = $config.name
            $key = $config.key1
            $model_name = $config.properties.model.name
            $model_version = $config.properties.model.version
            
            # if $modename & $modelversion both empty, then output all
            # if $modename & $modelversion both not empty then $model_name -eq $modelname -and $model_version -eq $modelversion, output 
            # if $modename is empty and $modelversion is not empty, then output all match modelversion only
            # if $modename is not emty and $modelversion is empty, then output all match modelname only 

            if ([string]::IsNullOrEmpty($modelname) -and [string]::IsNullOrEmpty($modelversion)) {
                write-host "[$($model_name) , version $($model_version)]" -ForegroundColor "DarkCyan"
                write-host "   -apikey ""$key"" -DeploymentName ""$($deployment)"" -endpoint ""$endpoint"" " -ForegroundColor "gray"
            }  

            if ([string]::IsNullOrEmpty($modelname) -and ![string]::IsNullOrEmpty($modelversion)) {
                if ($model_version -eq $modelversion) {
                    write-host "[$($model_name) , version $($model_version)]" -ForegroundColor "DarkCyan"
                    write-host "   -apikey ""$key"" -DeploymentName ""$($deployment)"" -endpoint ""$endpoint"" " -ForegroundColor "gray"
                }
            }

            if (![string]::IsNullOrEmpty($modelname) -and [string]::IsNullOrEmpty($modelversion)) {
                if ($model_name -eq $modelname) {
                    write-host "[$($model_name) , version $($model_version)]" -ForegroundColor "DarkCyan"
                    write-host "   -apikey ""$key"" -DeploymentName ""$($deployment)"" -endpoint ""$endpoint"" " -ForegroundColor "gray"
                }
            }

            if (![string]::IsNullOrEmpty($modelname) -and ![string]::IsNullOrEmpty($modelversion)) {
                if ($model_name -eq $modelname -and $model_version -eq $modelversion) {
                    write-host "[$($model_name) , version $($model_version)]" -ForegroundColor "DarkCyan"
                    write-host "   -apikey ""$key"" -DeploymentName ""$($deployment)"" -endpoint ""$endpoint"" " -ForegroundColor "gray"
                }
            }
        }
    }
    else {
        Write-UTCLog "$($env:userprofile)\.azureai\azureai-config.json does not exist, please refer help" -color "Red"    
    }
    exit 
}

# Validate Azure AI parameters, when v1 & v2 all parameter is not configure 
#if (!$endpoint -or !$DeploymentName -or !$apikey -or !$modelname -or !$modelversion) { 
if ([string]::IsNullOrEmpty($endpoint) -and [string]::IsNullOrEmpty($DeploymentName) -and [string]::IsNullOrEmpty($apikey) -and [string]::IsNullOrEmpty($modelname) -and [string]::IsNullOrEmpty($modelversion)){ 
    # if azureai-config_last.json exist, read the configuration 
    if (Test-path "$($env:USERPROFILE)\.azureai\azureai-config_last.json")
    {
        if ($debug) {Write-UTCLog "Use last config file: $($env:USERPROFILE)\.azureai\azureai-config_last.json" -color "Gray"}
        $openai_configs=(get-content "$($env:USERPROFILE)\.azureai\azureai-config_last.json")|convertfrom-json
        $endpoint = $openai_configs.endpoint
        $DeploymentName = $openai_configs.DeploymentName
        $apikey = $openai_configs.apikey
    }
    else {
        Write-UTCLog "Azure OpenAi Config v1, v2, azureai-config_last.json are not set, exit now. Please refer .\build_azure-config.ps1(v2) or .\env_setup.cmd (v1) or config endpoint/deployment/apikey" -color "Red"; 
        exit
    }
}

if (![string]::IsNullOrEmpty($endpoint) -and ![string]::IsNullOrEmpty($DeploymentName) -and ![string]::IsNullOrEmpty($apikey))
{
    if ($debug) {Write-UTCLog "v1 Configuration or azureai-config_last are used" -color "DarkCyan"}
}
else {
    # if v2 configuration is set, then use v2 configuration
    if ((![string]::$modelname) -and (Test-path "$($env:USERPROFILE)\.azureai\azureai-config.json" ))
    {
        Write-UTCLog "v2 Configuration is set" -color "DarkCyan"
        $openai_configs=(get-content "$($env:USERPROFILE)\.azureai\azureai-config.json")|convertfrom-json
        $configObjects = @()  # create empty array
        foreach ($config in $openai_configs)
        {
            # both $modelname and $modelversion are specified
            if (![string]::IsNullOrEmpty($modelname) -and ![string]::IsNullOrEmpty($modelversion)) {
                if (($config.properties.model.name -eq $modelname) -and ($config.properties.model.version -eq $modelversion)) {
                    $c = New-Object PSObject
                    $c | Add-Member -MemberType NoteProperty -Name location -Value $config.location
                    $c | Add-Member -MemberType NoteProperty -Name endpoint -Value "https://$($config.Id.split("/")[8]).openai.azure.com/"
                    $c | Add-Member -MemberType NoteProperty -Name DeploymentName -Value $config.name
                    $c | Add-Member -MemberType NoteProperty -Name apikey -Value $config.key1
                    $c | Add-Member -MemberType NoteProperty -Name model_name -Value $config.properties.model.name
                    $c | Add-Member -MemberType NoteProperty -Name model_version -Value $config.properties.model.version
                    $configObjects += $c
                }
            }

            # only $modelname is specified
            if (![string]::IsNullOrEmpty($modelname) -and [string]::IsNullOrEmpty($modelversion)) {
                if ($config.properties.model.name -eq $modelname) {
                    $c = New-Object PSObject
                    $c | Add-Member -MemberType NoteProperty -Name location -Value $config.location
                    $c | Add-Member -MemberType NoteProperty -Name endpoint -Value "https://$($config.Id.split("/")[8]).openai.azure.com/"
                    $c | Add-Member -MemberType NoteProperty -Name DeploymentName -Value $config.name
                    $c | Add-Member -MemberType NoteProperty -Name apikey -Value $config.key1
                    $c | Add-Member -MemberType NoteProperty -Name model_name -Value $config.properties.model.name
                    $c | Add-Member -MemberType NoteProperty -Name model_version -Value $config.properties.model.version
                    $configObjects += $c
                }
            }

            # only $modelversion is specified
            if ([string]::IsNullOrEmpty($modelname) -and ![string]::IsNullOrEmpty($modelversion)) {
                if ($config.properties.model.version -eq $modelversion) {
                    $c = New-Object PSObject
                    $c | Add-Member -MemberType NoteProperty -Name location -Value $config.location
                    $c | Add-Member -MemberType NoteProperty -Name endpoint -Value "https://$($config.Id.split("/")[8]).openai.azure.com/"
                    $c | Add-Member -MemberType NoteProperty -Name DeploymentName -Value $config.name
                    $c | Add-Member -MemberType NoteProperty -Name apikey -Value $config.key1
                    $c | Add-Member -MemberType NoteProperty -Name model_name -Value $config.properties.model.name
                    $c | Add-Member -MemberType NoteProperty -Name model_version -Value $config.properties.model.version
                    $configObjects += $c
                }
            }
        }
        # create random number between 0 and $configObjects.count
        if ($configObjects.count -eq 0) {
            Write-UTCLog "No matching model found, please check '-listconfig -modelname $($modelname) -modelversion $($modelversion)' and verify if there is a result" -color "Red"
            exit
        }

        if ($configObjects.count -eq 1) {  # if only 1 model found, use it
            $endpoint = $configObjects[0].endpoint
            $DeploymentName = $configObjects[0].DeploymentName
            $apikey = $configObjects[0].apikey
            $model_name = $configObjects[0].model_name
            $model_version = $configObjects[0].model_version
        }
        else { # if more than 1 model found, use random one
            $random = Get-Random -Minimum 0 -Maximum $configObjects.count
            $endpoint = $configObjects[$random].endpoint
            $DeploymentName = $configObjects[$random].DeploymentName
            $apikey = $configObjects[$random].apikey
            $model_name = $configObjects[$random].model_name
            $model_version = $configObjects[$random].model_version
        }
    }
    else {
        write-UTCLog "v2 Configuration will be used, either -modelname or $($env:USERPROFILE)\.azureai\azureai-config.json is missing" -color "Red"
    }
}

# review configuration is correct if there any of the following are null, exit
if ([string]::IsNullOrEmpty($endpoint) -and [string]::IsNullOrEmpty($DeploymentName) -and [string]::IsNullOrEmpty($apikey))
{
    Write-UTCLog "Endpoint, DeploymentName, apikey are not set from v1/v2 configuration, exit now." -color "Red";
    exit
}
else {
    Write-UTCLog "Endpoint : $($endpoint) , Deployment : $($DeploymentName)" -color "gray"    <# Action when all if and elseif conditions are false #>
}

# if token is empty 
# then check if we have maxtoken_input and maxtoken_output if that is not set, use default 8096
if (!$token) { 
    if ($maxtoken_input -and $maxtoken_output) {
        $token = $maxtoken_output
        #Write-UTCLog "MaxTokens_Input (Env) : $($maxtoken_input)" -color "gray" 
        #Write-UTCLog "MaxTokens_Output(Env) : $($token)" -color "gray" 
    }
    else {
        $token = 8096
        #Write-UTCLog "MaxToken(Default): $($token)" -color "gray" 
    }
}
else {
    #Write-UTCLog "MaxToken(Env) : $($token)" -color "gray" 
}

# build out the prompt text
# primary choice -prompt 
# secondary choice -promptFile
# third choice -promptchoice 
if (![string]::IsNullOrEmpty($prompt)) {
    $promptText = $prompt
    Write-UTCLog "Prompt(Custom): $promptText" -color "DarkCyan" 
    #get strlen of $promptText
    $promptforlogging = "PromptCustom: $($promptText.length) chars"
}
else {
    if ($promptFile -and (Test-Path $promptFile)) {
        $promptText = Get-Content $promptFile -Raw
        Write-UTCLog "PromptFile system, use prompt from custom file: $promptFile" -color "DarkCyan" 
        $promptforlogging = "PromptFile: $($promptFile)" 
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
            if (Test-Path "$($env:temp)\prompt.json") {
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

$stoken = Get-ContentTokens $promptText

# Check if contentFile is specified and exists
if ($contentFile -and (Test-Path $contentFile)) {
    $content = Get-Content $contentFIle -Raw
}

# Get Token count of the content
$utoken = Get-ContentTokens $content

# if content is too long, only print first 100 characters
if ($content.length -ge 100) { $offset = 100 } else { $offset = $content.length }
Write-UTCLog "Content(user) : $($content.Substring(0,$offset)) [max first 100 chars]" "Yellow"

# check if token is too large
<#
if ($maxtoken_input -and $maxtoken_output)
{
    # checkinput token only for GPT-4 or 3.5 1106
    if (($maxtoken_input- $utoken - $stoken) -lt 0) {
        Write-UTCLog "Error: Prompt Token is too large (> $($maxtoken_input)), please reduce size of content,contentfile , exit." -color "Red"
        Write-UTCLog "Tokens        : user=$($utoken) , system=$($stoken) , tokens_input=$($utoken + $stoken)" -color "Red"
        exit
    }
    else {
        Write-UTCLog "Tokens        : user=$($utoken) , system=$($stoken) , tokens_inputs=$($utoken + $stoken)" -color "Green"
        $t0 = Get-Date
        # Use $token as Max Return token for GPT call
        $chat = Invoke-ChartGPTCompletion -Endpoint $endpoint -AccessKey $apikey -DeploymentName $DeploymentName -Prompt $promptText -Message $content -Token $($token) -Temperature $temperature
    }
}
else {
    # checkinput token for GPT-4 or 3.5 before 1106 
    if (($token - $utoken - $stoken) -lt 0) {
        Write-UTCLog "Error: Prompt Token is too large, please reduce size of content,contentfile , exit." -color "Red"
        Write-UTCLog "Tokens        : user=$($utoken) , system=$($stoken) , max_tokens=$($token - $utoken -$stoken)" -color "Red"
        exit
    }
    else {
        Write-UTCLog "Tokens        : user=$($utoken) , system=$($stoken) , max_tokens=$($token - $utoken -$stoken)" -color "Green"
        $t0 = Get-Date
        # Use $token - $tokenCount as Max Return token for GPT call
        $chat = Invoke-ChartGPTCompletion -Endpoint $endpoint -AccessKey $apikey -DeploymentName $DeploymentName -Prompt $promptText -Message $content -Token $([int]($token - $utoken - $stoken)) -Temperature $temperature
    }
}#>
Write-UTCLog "Tokens        : user=$($utoken) , system=$($stoken) , tokens_inputs=$($utoken + $stoken).  Temperature : $($temperature)" -color "Green"
$t0 = Get-Date
$chat = Invoke-ChartGPTCompletion -Endpoint $endpoint -AccessKey $apikey -DeploymentName $DeploymentName -Prompt $promptText -Message $content -Temperature $temperature
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

#save the last used configuration $endpoint, $deploymentname, $apikey to $profile\.azureai\azureai_config_last.json
if (!$DonotUpdateLastConfig)
{
    $lastconfigjson=@()
    $lastconfig = New-Object PSObject
    $lastconfig | Add-Member -MemberType NoteProperty -Name endpoint -Value $endpoint
    $lastconfig | Add-Member -MemberType NoteProperty -Name DeploymentName -Value $DeploymentName
    $lastconfig | Add-Member -MemberType NoteProperty -Name apikey -Value $apikey
    $lastconfigjson += $lastconfig
    $lastconfigjson | ConvertTo-Json | Out-File "$($env:USERPROFILE)\.azureai\azureai-config_last.json" -Encoding utf8
    if ($debug) {Write-UTCLog "Last used configuration saved to $($env:USERPROFILE)\.azureai\azureai-config_last.json" -color "gray"  }
}
else {
    if ($debug) {Write-UTCLog "Last used configuration is not updated" -color "gray"}
}

# print out the result
Write-UTCLog "AI thinking time: $($delta) seconds"  -color "Cyan"

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

if ([string]::IsNullOrEmpty($aikey)) {
    if ($debug) { Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "DarkCyan" }
} 
else {
    if ($debug) { Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "DarkCyan" }

    #get hostname from $endpoint and retrieve the name before .openai.azure.com
    Send-AIEvent -piKey $aikey -pEventName $scriptname -pCustomProperties @{DeploymentName = $DeploymentName.tostring(); chatid = $chat.id.tostring();
        object = $chat.object.tostring(); model = $chat.model.tostring(); CreatedTime = $datetime; token_completion = $chat.usage.completion_tokens;
        token_prompt = $chat.usage.prompt_tokens; token_total = $chat.usage.total_tokens; promptchoice = $promptforlogging; endpoint = $endpoint.split("/")[2].tostring() ; AIResponseTimeE2E = $delta;temperature = $temperature; 
    }
    # CreatedTime is not accurate this is the time when i log the Send-AIEvnet
}
