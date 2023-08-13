<#
.SYNOPSIS
Work with AzureAI GPT-3.5 API.

.DESCRIPTION
This script is used to work with AzureAI GPT API, send content to AzureAI and get the response. 
Allow user to select different prompt from prompt.json to fine tune the response.

.PARAMETER content
Content to be sent to AzureAI GPT-3.5 API

.PARAMETER endpoint
AzureAI GPT-3.5 API endpoint, for example "https://<Azure AI Endpoint>.openai.azure.com/"

.PARAMETER DeploymentName
DeploymentName for AzureAI GPT-3.5 API

.PARAMETER apikey
apikey for AzureAI GPT-3.5 API

.PARAMETER promptchoice
promptchoice , that matches prompt.json file 

.PARAMETER aikey
GUID, Instrumentation Key used by Application Insight

.EXAMPLE
Use Default template to ask GPT "what to eat today"
.\invoke-azureai-gpt.ps1 -content "What to eat today" -promptchoice "Default"

.EXAMPLE
Use Chinese to English template to ask GPT "what to eat today"
.\invoke-azureai-gpt.ps1 -content "What to eat today" -promptchoice "Chinese to English"

.EXAMPLE
Use Chinese to English template to ask GPT "what to eat today" and overwrite deployment in enviornment 
.\invoke-azureai-gpt.ps1 -content "What to eat today" -promptchoice "Chinese to English" -deploymentname "gpt3-5-2021-04-08-01"

.NOTES
Author: qliu
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
    [string] $content="What to eat today",
    [string] $endpoint, # endpoint for AzureAI
    [string] $DeploymentName, # deployment name for AzureAI
    [string] $apikey, # deployment name for AzureAI
    [ValidateSet('Default','Text Polish','Chinese to English','English to Chinese','Code Re-Factory','Explain Code','Summarize Text','Echo','Powershell Sample Code','Python Sample Code','KQL ADX')][string]$promptchoice="Default",
    [guid]   $aikey  #Provide Application Insigt instrumentation key 
)

#logging
Function Write-UTCLog ([string]$message,[string]$color="white")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
#    	Write-Output $logstamp | Out-File $logfile -Encoding ASCII -append
}

# Powershell Function Send-AIEvent , 2023-04-08
Function Send-AIEvent{
    param (
                [Guid]$piKey,
                [String]$pEventName,
                [Hashtable]$pCustomProperties,
                [string]$logpath="c:\temp\"
    )
        $appInsightsEndpoint = "https://dc.services.visualstudio.com/v2/track"        
        
        if ([string]::IsNullOrEmpty($env:USERNAME)) {$uname=($env:USERPROFILE).split('\')[2]} else {$uname=$env:USERNAME}
        if ([string]::IsNullOrEmpty($env:USERDOMAIN)) {$domainname=$env:USERDOMAIN_ROAMINGPROFILE} else {$domainname=$env:USERDOMAIN}
            
        $body = (@{
                name = "Microsoft.ApplicationInsights.$iKey.Event"
                time = [DateTime]::UtcNow.ToString("o")
                iKey = $piKey
                tags = @{
                    "ai.user.id" = $uname
                    "ai.user.authUserId" = "$($domainname)\$($uname)"
                    "ai.cloud.roleInstance" = $env:COMPUTERNAME
                    "ai.device.osVersion" = [System.Environment]::OSVersion.VersionString
                    "ai.device.model"= (Get-CimInstance CIM_ComputerSystem).Model

          }
            "data" = @{
                    baseType = "EventData"
                    baseData = @{
                        ver = "2"
                        name = $pEventName
                        properties = ($pCustomProperties | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
                    }
                }
            }) | ConvertTo-Json -Depth 10 -Compress
    
        $temp = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"

        $attempt=1
        do {
            try {
                Invoke-WebRequest -Method POST -Uri $appInsightsEndpoint -Headers @{"Content-Type"="application/x-json-stream"} -Body $body -TimeoutSec 3 -UseBasicParsing| Out-Null 
                return    
            }
            catch {
                $PreciseTimeStamp=($timeStart.ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
                if ($attempt -ge 4)
                {
                    Write-Output "retry 3 failure..." 
                    $sendaimessage =$PreciseTimeStamp+",Fail to send AI message after 3 attemps, message lost"
                    $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                    return $null
                }
                Write-Output "Attempt($($attempt)): send aievent failure, retry" 
                $sendaimessage =$PreciseTimeStamp+", Attempt($($attempt)) , wait 1 second, resend AI message"
                $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                Start-Sleep -Seconds 1
            }
            $attempt++
        } until ($success)
        $ProgressPreference = $temp
}


## Invoke-AzureAI-GPT

Function Invoke-ChartGPTCompletion {
    Param(
        [Parameter(Mandatory = $true)][string]$endpoint,
        [Parameter(Mandatory = $true)][string]$AccessKey,
        [Parameter(Mandatory = $true)][string]$DeploymentName,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $url = "$($endpoint)openai/deployments/$DeploymentName/chat/completions?api-version=2023-03-15-preview"
    Write-UTCLog "AI Endpoints: $($url)" "Green"
    Write-UTCLog "Question : $($Message)" "Yellow"
    $headers = @{
        "api-key" = $AccessKey
    }

    $promptPayload = [PSCustomObject]@{
        "content" = $Prompt
        "role"    = "system"
    }

    $messagePayload = [PSCustomObject]@{
        "content" = $Message
        "role"    = "user"
    }

    $payload = [PSCustomObject]@{
        "model"             = $DeploymentName
        "frequency_penalty" = 0
        "max_tokens"        = 4000
        "messages"          = @($promptPayload, $messagePayload)
        "presence_penalty"  = 0
        "stream"            = $false
        "temperature"       = 0.7
        "top_p"             = 0.95
    }

    # return $payload
    $body = ConvertTo-Json -InputObject $payload -Compress 
    
    Write-UTCLog "Payload: $($body)" "Yellow"

    #$body = $body -creplace '\P{IsBasicLatin}'  # this leaves only ASCII characters does not accept the chinese characters
    $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json;charset=utf-8' 
    return $result;
}

# main program started

# verify the current folder has prompt.json file
$promptfile = "$($PSScriptRoot)\prompt.json"

if (Test-Path $promptfile) {
    # use $promptchoice to select the prompt from the json file
    $promptjson = Get-Content $promptfile -Encoding UTF8 | ConvertFrom-Json 
    $prompt = ($promptjson| Where-Object {$_.'name_en-us' -eq $promptchoice}).prompt
    $promptchoicezhcn = ($promptjson| Where-Object {$_.'name_en-us' -eq $promptchoice}).name
    if ([string]::IsNullOrEmpty($prompt)) {
        $prompt = "You are an AI assistant that helps people find information."
        $promptchoicezhcn = "默认"        
    }
}
else {
    $prompt = "You are an AI assistant that helps people find information."
    $promptchoicezhcn = "默认"
}

# initalize variables, if not set, try to use $env parameter, if that is empty too, return false
if ([string]::IsNullOrEmpty($endpoint)) {$endpoint=$env:OPENAI_ENDPOINT_AZURE} else {$endpoint=$endpoint}
if ([string]::IsNullOrEmpty($DeploymentName)) {$DeploymentName=$env:OPENAI_ENGINE_AZURE} else {$DeploymentName=$DeploymentName}
if ([string]::IsNullOrEmpty($apikey)) {$apikey=$env:OPENAI_API_KEY_AZURE} else {$endpoint=$endpoint}

# all parameter must be set to continue

if ([string]::IsNullOrEmpty($endpoint)) {Write-UTCLog "Endpoint is not set, exit. Please use evn_setup.cmd to config endpoint/deployment/apikey" -color "Red"; return $false}
if ([string]::IsNullOrEmpty($DeploymentName)) {Write-UTCLog "DeploymentName is not set, exit. Please use evn_setup.cmd to config endpoint/deployment/apikey" -color "Red"; return $false}
if ([string]::IsNullOrEmpty($apikey)) {Write-UTCLog "apikey is not set, exit. Please use evn_setup.cmd to config endpoint/deployment/apikey" -color "Red"; return $false}

Write-UTCLog "Endpoint: $($endpoint)" -color "Green"
Write-UTCLog "DeploymentName: $($DeploymentName)" -color "Green"
Write-UTCLog "apikey: *****************" -color "Green"
Write-UTCLog "PromptChoice: $($promptchoice) , $($promptchoicezhcn)" -color "blue"
Write-UTCLog "Prompt: $($prompt)" -color "blue"

$t0=Get-Date
$chat = Invoke-ChartGPTCompletion -Endpoint $($endpoint) -AccessKey $($apikey) -DeploymentName $($DeploymentName) -Prompt $prompt -Message $content
$t1=Get-Date
$suggestion = $chat.choices[0].message.content

if ($PSVersionTable['PSVersion'].Major -eq 5) {
    $dstEncoding = [System.Text.Encoding]::GetEncoding('iso-8859-1')
    $srcEncoding = [System.Text.Encoding]::UTF8
    $suggestion = $srcEncoding.GetString([System.Text.Encoding]::Convert($srcEncoding, $dstEncoding, $srcEncoding.GetBytes($chat.choices[0].message.content)))
}
else {
    $suggestion = $chat.choices[0].message.content
}

# get delta time between $t1 and t0 in seconds and in format of xx.xx
$delta = "{0:N2}" -f ($t1-$t0).TotalSeconds

# print out the result
Write-UTCLog "AI thinking time: $($delta) seconds"  -color "Cyan"
Write-Host "---------------------------------------------------------" -ForegroundColor "Cyan"
# Unix Epoch time to UTC time
$unixEpoch = [datetime]'1/1/1970 00:00:00Z'
$dateTime = $unixEpoch.AddSeconds($($chat.created)).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

# output the result properties
Write-Host "Id               : $($chat.id)" -ForegroundColor "gray"
Write-Host "Object           : $($chat.object)" -ForegroundColor "gray"
Write-Host "Model            : $($chat.model)" -ForegroundColor "gray"
Write-Host "CreateTime       : $($dateTime)" -ForegroundColor "gray"
Write-Host "Token_Completion : $($chat.usage.completion_tokens)" -ForegroundColor "gray"
Write-Host "Token_Prompt     : $($chat.usage.prompt_tokens)" -ForegroundColor "gray"
Write-Host "Token_Total      : $($chat.usage.total_tokens)" -ForegroundColor "gray"

Write-Host "---------------------------------------------------------" -ForegroundColor "Cyan"
Write-Host "$($suggestion)" -ForegroundColor "Cyan"
Write-Host "---------------------------------------------------------" -ForegroundColor "Cyan"

if ([string]::IsNullOrEmpty($aikey)) {
    #Write-Host "Info : aikey is not specified, Send-AIEvent() is skipped." -ForegroundColor "Gray"
} 
else 
{
    Write-Host "Info : aikey is specified, Send-AIEvent() is called" -ForegroundColor "Green"
    Send-AIEvent -piKey $aikey -pEventName "invoke-azureapi-gpt.ps1" -pCustomProperties @{DeploymentName=$DeploymentName.tostring();chatid=$chat.id.tostring();object=$chat.object.tostring();model=$chat.model.tostring();CreatedTime=$datetime;token_completion=$chat.usage.completion_tokens;token_prompt=$chat.usage.prompt_tokens;token_total=$chat.usage.total_tokens}
}


