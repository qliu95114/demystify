# this script build out the azureai-config.ps1 
# the script will search all the resource group that has OpenAI resource and get the deployment id and name
# the script will then append the result to %userprofile%\.azureai\azureai-config.json

Param(
    [string] $subscriptionId
)

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. $scriptDir\utils.ps1

# connect-azaccount to login azure
# get current user bear token and set it to $usertoken
# detect if Az.ResourceGraph is not installed installed it via 'Install-Module -Name Az.ResourceGraph  '
# search-azgroup "resources | where type == 'microsoft.cognitiveservices/accounts' | where kind == 'OpenAI'"
# the script then lopp all the resource group and get the resource id and name and call 
# https://management.azure.com/subscriptions/64cebcee-f000-4c0d-9e51-edc3778ff221/resourceGroups/openai_2023_08/providers/Microsoft.CognitiveServices/accounts/naniteopenai4/deployments?api-version=2023-10-01-preview
# to get the deployment id and name  
# append the result to %userprofile%\.azureai\azureai-config.json

# determine if connect-azaccount is available, if not install az module
if ((Get-Module -ListAvailable -Name Az.Accounts).count -gt 0) {
    Write-UTCLog "Az.Accounts module is installed" "Gray"
} else {
    Write-UTCLog "Az.Accounts module is not installed, installing..." "Yellow"
    Install-Module -Name Az.Accounts -Force
}

# detect if Az.ResourceGraph is not installed installed it via 'Install-Module -Name Az.ResourceGraph  '
if ((Get-Module -ListAvailable -Name Az.ResourceGraph).count -gt 0) {
    Write-UTCLog "Az.ResourceGraph module is installed" "Gray"
} else {
    Write-UTCLog "Az.ResourceGraph module is not installed, installing..." "Yellow"
    Install-Module -Name Az.ResourceGraph -Force
}

if ($subcount=Get-AzSubscription | Measure-Object | Select-Object -ExpandProperty Count) {
    Write-UTCLog "You have $subcount subscriptions" "Gray"
} else {
    Write-UTCLog "You have no subscriptions, please login to Azure" "Red"
    Connect-AzAccount -ErrorAction SilentlyContinue
}

# get current user bear token and set it to $usertoken
$usertoken = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction SilentlyContinue
$usertoken = "Bearer " + $usertoken.Token
$headers = @{
    'Authorization' = $usertoken
}
Write-UTCLog "Get current user Bearer token" "Gray"

#if subid is not provided, get all the resource group
if ($subscriptionId -eq "") {
    $qry = "resources | where type == 'microsoft.cognitiveservices/accounts' | where kind == 'OpenAI'"
} else {
    $qry = "resources | where type == 'microsoft.cognitiveservices/accounts' | where kind == 'OpenAI' | where subscriptionId =~ '$($subscriptionId)'" 
}

$result = Search-AzGraph -Query $qry -ErrorAction SilentlyContinue
#$result # Format-Table -AutoSize

# if output folder does not exist , create one 
if (!(Test-Path "$($env:USERPROFILE)\.azureai")) {
    New-Item -Path "$($env:USERPROFILE)\.azureai" -ItemType Directory -Force
}

# if output file exist, request user to confirm before overwrite
if (Test-Path "$($env:USERPROFILE)\.azureai\azureai-config.json") {
    $confirm = Read-Host "$($env:USERPROFILE)\.azureai\azureai-config.json already exist, do you want to overwrite it? (y/n)"
    if ($confirm -eq "y") {
        Remove-Item "$($env:USERPROFILE)\.azureai\azureai-config.json" -Force
    } else {
        exit
    }
}

$json_all=@()

# loop all the resource group and get the resource id and name and call
foreach ($subid in $result)
{
    $location=$subid.location
    $sku=$subid.sku.name
    # get all deployment id and name from Azure OpenAI resource
    $url="https://management.azure.com/subscriptions/$($subid.subscriptionId)/resourceGroups/$($subid.resourceGroup)/providers/Microsoft.CognitiveServices/accounts/$($subid.name)/deployments?api-version=2023-10-01-preview"
    #Write-Host $url
    $jsonresult=Invoke-RestMethod -Uri $url -Headers $headers -Method Get 

    # get-key key of Azure OpenAI resource
    Select-AzSubscription -subscriptionid $subid.subscriptionId -ErrorAction SilentlyContinue | Out-Null
  
    $key=""
    $key=Get-AzCognitiveServicesAccountKey -ResourceGroupName $subid.resourceGroup -Name $subid.name -ErrorAction SilentlyContinue

    if ([string]::IsNullOrEmpty($key)) {
        Write-UTCLog "(Fail) Save configuration from subscription $($subid.subscriptionId):$($subid.name), please check if you have contributor permission to the resource."  "Red"
    }
    else {
        Write-UTCLog "(Success) Save configuration from subscription $($subid.subscriptionId):$($subid.name)" "Green"
        $json = $jsonresult.value | ConvertTo-Json -Depth 100 | convertfrom-json 
        foreach ($deployment in $json)
        {
            #add location and sku to $deployment
            $deployment | Add-Member -MemberType NoteProperty -Name location -Value $location
            $deployment | Add-Member -MemberType NoteProperty -Name skuname -Value $sku
            $deployment | Add-Member -MemberType NoteProperty -Name key1 -Value $key.Key1
            $deployment | Add-Member -MemberType NoteProperty -Name key2 -Value $key.Key2
    
            #add $deployment to $json_all
            $json_all += $deployment
        }
    }
    # add extra atrributes to the json file
}

#output json_all to json file
$json_all | ConvertTo-Json -Depth 100 | Out-File "$($env:USERPROFILE)\.azureai\azureai-config.json"

Write-UTCLog "azureai-config.json is created at $($env:USERPROFILE)\.azureai\azureai-config.json" "Green"
Write-UTCLog "Please use '.\invoke-azureai-gpt -listconfig' to see sample " "Green"




