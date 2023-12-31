#logging
Function Write-UTCLog ([string]$message, [string]$color = "white") {
    $logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    $logstamp = "[" + $logdate + "]," + $message
    Write-Host $logstamp -ForegroundColor $color
}


# Copy function from code365scripts.openai
function Get-IsValidImage($path) {
    # check if the url is a valid url for image, mediatype is jpg, png, gif
    $valid = $false

    # if the path is a local file path, then check if the file is a valid image file
    if (Test-Path $path -PathType Leaf) {
        $extension = [System.IO.Path]::GetExtension($path).TrimStart(".")
        if ($extension -match "^(jpg|jpeg|png|gif)$") {
            $valid = $true
        }
    }
    elseif($path -match "^https?://") {
        # send a head request to the url to check the header, 
        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
        # if the "Content-Type" is image/jpg or image/png or image/gif, then it is a valid
        if ($response.Headers["Content-Type"] -match "image/(jpg|jpeg|png|gif)") {
            $valid = $true
        }
    }

    return $valid

}
function Get-OnlineImageBase64Uri($url) {
    # Create a new WebClient instance
    $webClient = New-Object System.Net.WebClient

    # Download the image data
    $imageData = $webClient.DownloadData($url)

    # Convert the image data to base64
    $base64 = [System.Convert]::ToBase64String($imageData)

    # Get the image type from the URL
    $type = if ($url -match "\.(\w+)$") { $Matches[1] } else { "png" }

    # Create the data URI
    $uri = "data:image/$type;base64=$base64" 


    return $uri
}

function Get-ImageBase64Uri($file) {
    # if the file is a local file path, then read the file as byte array
    if (Test-Path $file -PathType Leaf) {
        Write-UTCLog "Imagefile     : $file , convert to BASE64" -color "Yellow"
        $image = [System.IO.File]::ReadAllBytes($file)
        # get extension without dot
        $type = [System.IO.Path]::GetExtension($file).TrimStart(".")
        $base64 = [System.Convert]::ToBase64String($image)
        $uri = "data:image/$($type);base64,$($base64)"
        #$uri = """$($base64)"""
        return $uri
    }

    if ($file -match "^https?://") {
        Write-Verbose "Prompt is a url, read the url as prompt"
        $uri = Get-OnlineImageBase64Uri -url $file

        return $uri
    }
}


# Powershell Function Send-AIEvent , 2023-08-12 , fix bug in retry logic
Function Send-AIEvent {
    param (
        [Guid]$piKey,
        [String]$pEventName,
        [Hashtable]$pCustomProperties,
        [string]$logpath = $env:temp
    )
    $appInsightsEndpoint = "https://dc.services.visualstudio.com/v2/track"

    if ([string]::IsNullOrEmpty($env:USERNAME)) { $uname = ($env:USERPROFILE).split('\')[2] } else { $uname = $env:USERNAME }
    if ([string]::IsNullOrEmpty($env:USERDOMAIN)) { $domainname = $env:USERDOMAIN_ROAMINGPROFILE } else { $domainname = $env:USERDOMAIN }
            
    $body = (@{
            name   = "Microsoft.ApplicationInsights.$iKey.Event"
            time   = [DateTime]::UtcNow.ToString("o")
            iKey   = $piKey
            tags   = @{
                "ai.user.id"            = $uname
                "ai.user.authUserId"    = "$($domainname)\$($uname)"
                "ai.cloud.roleInstance" = $env:COMPUTERNAME
                "ai.device.osVersion"   = [System.Environment]::OSVersion.VersionString
                "ai.device.model"       = (Get-CimInstance CIM_ComputerSystem).Model

            }
            "data" = @{
                baseType = "EventData"
                baseData = @{
                    ver        = "2"
                    name       = $pEventName
                    properties = ($pCustomProperties | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
                }
            }
        }) | ConvertTo-Json -Depth 10 -Compress
    
    $temp = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"

    $attempt = 1
    do {
        try {
            Invoke-WebRequest -Method POST -Uri $appInsightsEndpoint -Headers @{"Content-Type" = "application/x-json-stream" } -Body $body -TimeoutSec 3 -UseBasicParsing | Out-Null 
            return    
        }
        catch {
            $PreciseTimeStamp = (get-date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
            if ($attempt -ge 4) {
                Write-Output "retry 3 failure..." 
                $sendaimessage = $PreciseTimeStamp + ",Fail to send AI message after 3 attemps, message lost"
                $sendaimessage | Out-File "$($logpath)\aimessage.log" -Append -Encoding utf8
                return $null
            }
            Write-Output "Attempt($($attempt)): send aievent failure, retry" 
            $sendaimessage = $PreciseTimeStamp + ", Attempt($($attempt)) , wait 1 second, resend AI message"
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
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$token=8000,
        [single]$temperature=0.7
    )
    
    #"2023-07-01-preview"  "2023-05-15"
    $api_version = "2023-07-01-preview"
    
    $url = "$($endpoint)openai/deployments/$($DeploymentName)/chat/completions?api-version=$($api_version)"
    if ($debug) { Write-UTCLog "AI Endpoints: $($url)" "DarkCyan" }

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
        #"max_tokens"       = $token  #remve api token limit and see what we will have
        "messages"          = @($promptPayload, $messagePayload)
        "presence_penalty"  = 0
        "stream"            = $false
        "temperature"       = $temperature
        "top_p"             = 0.95
    }

    # return $payload
    $body = ConvertTo-Json -InputObject $payload -Compress 
    
    if ($debug) { Write-UTCLog "Payload: $($body)" "DarkCyan" }
    #$body = $body -creplace '\P{IsBasicLatin}'  # this leaves only ASCII characters does not accept the chinese characters
    $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json;charset=utf-8' 
    return $result;
}

Function Invoke-ChartGPTCompletionVision {
    Param(
        [Parameter(Mandatory = $true)][string]$endpoint,
        [Parameter(Mandatory = $true)][string]$AccessKey,
        [Parameter(Mandatory = $true)][string]$DeploymentName,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][string]$Imagefile,
        [single]$temperature=0.7
    )
    
    #"2023-07-01-preview"  "2023-05-15"
    $api_version = "2023-07-01-preview"
    
    $url = "$($endpoint)openai/deployments/$($DeploymentName)/chat/completions?api-version=$($api_version)"
    if ($debug) { Write-UTCLog "AI Endpoints: $($url)" "DarkCyan" }

    $headers = @{
        "api-key" = $AccessKey
    }

    $promptPayload = [PSCustomObject]@{
        "content" = "You are an AI assistant that helps people find information"
        "role"    = "system"
    }

    $userTextPayload = [PSCustomObject]@{
        "type" = "text"
        "text" = $Message
    }

    # create imageURLPayload 
    $uri= [PSCustomObject]@{
        "url" = Get-ImageBase64Uri -file $Imagefile
    }

    $imageUrlPayload = [PSCustomObject]@{
        "type"    = "image_url"
        "image_url" = $uri
    }

    # Create UserPayload
    $userPayload = [PSCustomObject]@{
        "role"    = "user"
        "content" = @($imageUrlPayload,$userTextPayload)
    }

    #Write-Host $userPayload.content
    #Write-Host $userPayload.content.image_url

    $payload = [PSCustomObject]@{
        "model"             = $DeploymentName
        "frequency_penalty" = 0
        #"max_tokens"       = $token  #remve api token limit and see what we will have
        "messages"          = @($promptPayload, $userPayload)
        "presence_penalty"  = 0
        "stream"            = $false
        "temperature"       = $temperature
        "top_p"             = 0.95
    }

    # return $payload
    $body = ConvertTo-Json -InputObject $payload -Depth 10

    if ($debug) { Write-UTCLog "Payload: $($body)" "DarkCyan" }
    $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json;charset=utf-8' 
    if ($debug) { Write-UTCLog "Result: $($result)" "DarkCyan" }
    return $result;
}

# input parameters [string] $content, return tokens of the content 
function Get-ContentCJKTokens {
    param(
        [Parameter(Mandatory=$true)][string]$InputString
    )

    $CJKCharCount = 0
    #$stringContainsCJK = $false

    foreach ($char in $InputString.ToCharArray()) {
        if ([System.Char]::GetUnicodeCategory($char) -eq [System.Globalization.UnicodeCategory]::OtherLetter) {
            #$stringContainsCJK = $true
            $CJKCharCount++
        }
    }
    return $CJKCharCount
    #$output = New-Object PSObject
    #$output | Add-Member -MemberType NoteProperty -Name "ContainsCJK" -Value $stringContainsCJK
    #$output | Add-Member -MemberType NoteProperty -Name "CJKCharCount" -Value $CJKCharCount
}

function Get-ContentNumbersTokens {
    param (
        [string]$InputString
    )

    $numbersCount = 0

    foreach($char in $inputString.ToCharArray()){
        if([char]::IsDigit($char)) {
            $numbersCount++
        }
    }

    return $numbersCount
}


function Get-ContentTokens {
    param (
        [Parameter(Mandatory = $true)][string]$content
    )

    # we need to determine if $content is has Non-English characters CJK (Chinese,Japanese,Korean)
    # For CJK characters, tokens should be total CJK Char * 2
    # For Lartin (Non-CJK) characters, tokens will count the word, split by space

    # Add CJK chars, tokens  = CJK chars * 2
    $cjktokens = (Get-ContentCJKTokens -InputString $content) * 2 
    $numtokens = (Get-ContentNumbersTokens -InputString $content) 

    # Add Lartin characters only remove numbers, tokens , split by space and count the tokens
    $chs = "[\p{IsCJKUnifiedIdeographs}]"
    $jpn = "[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}\p{IsCJKSymbolsandPunctuation}]"
    $kor = "[\p{IsHangulJamo}\p{IsHangulSyllables}\p{IsHangulCompatibilityJamo}]"
    $chartokens=[int](($content -replace $chs, " " -replace $jpn, " " -replace $kor, " " -replace "\d"," " -replace "\s+", " " -replace "<", " " -replace ">", " " -replace "/", " " -split (" ")).count * 3) 
    $tokens = $cjktokens + $numtokens+ $chartokens # add 500 tokens for the prompt

    if ($debug) {Write-UTCLog "cjktokens: $cjktokens" "DarkCyan"}
    if ($debug) {Write-UTCLog "numberotoken: $numtokens" "DarkCyan"}
    if ($debug) {Write-UTCLog "chartokens: $chartokens" "DarkCyan"}
    
    return $tokens
}

# 2023-12-30 , add function to find model name and version from config file
function Find-ModelNameVersion{
    param (
        [Parameter(Mandatory = $true)][string]$endpoint,
        [Parameter(Mandatory = $true)][string]$name
    )
    if ($debug) {Write-UTCLog "Find-ModelNameVersion: endpointURL: $endpoint" -color "DarkCyan"}
    if ($debug) {Write-UTCLog "Find-ModelNameVersion: DeploymentName: $name" -color "DarkCyan"}
    
    # if file "$($env:USERPROFILE)\.azureai\azureai-config.json" exist and open it to get the model name and version
    $configfile = "$($env:USERPROFILE)\.azureai\azureai-config.json"
    if (Test-Path $configfile) {
        $config = Get-Content $configfile | ConvertFrom-Json
        # get extract endpoint name from the endpoint url
        $endpointname = $endpoint.split('/')[2].Split('.')[0]
        if ($debug) {Write-UTCLog "Find-ModelNameVersion: endpoint: $endpointname" -color "DarkCyan"}
        foreach ($c in $config)
        {
            $account=$c.id.split('/')[8]
            if ($account -eq $endpointname)
            {
                if ($debug) {Write-UTCLog "Find-ModelNameVersion: Match Endpoint found, $($c.id)" -color "DarkCyan"}
                if ($c.name -eq $name)
                {
                    if ($debug) {Write-UTCLog "Find-ModelNameVersion: Match Deployment found, $($c.name)" -color "DarkCyan"}
                    return $c.properties.model.name, $c.properties.model.version
                }
            }
        }
    }
    else {
        return $null,$null
    }

}
