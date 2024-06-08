# This script builds out the azureai-config.ps1
# The script searches all resource groups that have OpenAI resources and gets the deployment id and name
# The script then appends the result to %userprofile%\.azureai\azureai-config.json

Param(
    [string] $subscriptionId, # Support only one subscription id
    [string] $exclude_subid  # Used to remove subscription id from the result, supports only one subscription id
)

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. "$scriptDir\utils.ps1"

# connect-azaccount to login azure
# get current user bear token and set it to $usertoken
# detect if Az.ResourceGraph is not installed installed it via 'Install-Module -Name Az.ResourceGraph  '
# search-azgroup "resources | where type == 'microsoft.cognitiveservices/accounts' | where kind == 'OpenAI'"
# the script then lopp all the resource group and get the resource id and name and call 
# https://management.azure.com/subscriptions/64cebcee-f000-4c0d-9e51-edc3778ff221/resourceGroups/openai_2023_08/providers/Microsoft.CognitiveServices/accounts/naniteopenai4/deployments?api-version=2023-10-01-preview
# to get the deployment id and name  
# append the result to %userprofile%\.azureai\azureai-config.json

# Ensuring required modules are available
$modules = @("Az.Accounts", "Az.ResourceGraph", "Az.CognitiveServices")
foreach ($m in $modules) {
    if ((Get-Module -ListAvailable -Name $m).count -gt 0) {
        Write-UTCLog "$m module is installed" "Gray"
    }
    else {
        Write-UTCLog "$m module is not installed, installing..." "Yellow"
        Install-Module -Name $m -Force
        Write-UTCLog "$m module installation complete" "Green"
    }
}

# Login to Azure and get subscriptions
if ($subcount = Get-AzSubscription | Measure-Object | Select-Object -ExpandProperty Count) {
    $TenantId = (Get-AzContext).Tenant.id
    Write-UTCLog "TenantId: $TenantId " "Gray"
    Write-UTCLog "You have $subcount subscriptions" "Gray"
}
else {
    Write-UTCLog "You have no subscriptions, please login to Azure" "Red"
    Connect-AzAccount -ErrorAction SilentlyContinue
}

# Prepare headers with bearer token for REST calls
$usertoken = Get-AzAccessToken -ResourceUrl "https://management.azure.com/" -ErrorAction SilentlyContinue -TenantId $TenantId
if (-not $usertoken) {
    Write-UTCLog "Failed to obtain user token" "Red"
    exit
}

$headers = @{
    'Authorization' = "Bearer $($usertoken.Token)"
}
Write-UTCLog "Bearer token acquired" "Gray"

# Construct the query
$query = "resources | where type == 'microsoft.cognitiveservices/accounts' | where kind == 'OpenAI'"
if ($subscriptionId) {
    $query += " | where subscriptionId =~ '$subscriptionId'"
}
if ($exclude_subid) {
    $query += " | where subscriptionId !~ '$exclude_subid'"
}

Write-UTCLog "Executing query: $query" "Gray"
$result = Search-AzGraph -Query $query -ErrorAction SilentlyContinue

# Ensure the output directory exists
$outputDir = "$($env:USERPROFILE)\.azureai"
if (!(Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force
}

# Confirm before overwriting existing config file
$configFile = Join-Path -Path $outputDir -ChildPath "azureai-config.json"
if (Test-Path -Path $configFile) {
    $overwrite = Read-Host "$configFile already exists. Overwrite? (Y/N)"
    if ($overwrite.ToLower() -ne "y") {
        Write-UTCLog "Operation cancelled by user." "Yellow"
        exit
    }
    Remove-Item -Path $configFile -Force
}

$json_all = @()

# Loop all the resource group and get the resource id and name and call
foreach ($subid in $result) {
    $location = $subid.location
    $sku = $subid.sku.name
    # get all deployment id and name from Azure OpenAI resource
    $url = "https://management.azure.com/subscriptions/$($subid.subscriptionId)/resourceGroups/$($subid.resourceGroup)/providers/Microsoft.CognitiveServices/accounts/$($subid.name)/deployments?api-version=2023-10-01-preview"
    #Write-Host $url
    $jsonresult = Invoke-RestMethod -Uri $url -Headers $headers -Method Get 

    # get-key key of Azure OpenAI resource
    Select-AzSubscription -subscriptionid $subid.subscriptionId -ErrorAction SilentlyContinue  -TenantId $TenantId | Out-Null
    $key = Get-AzCognitiveServicesAccountKey -ResourceGroupName $subid.resourceGroup -Name $subid.name -ErrorAction SilentlyContinue

    if ([string]::IsNullOrEmpty($key)) {
        Write-UTCLog "(Fail) Save configuration from subscription $($subid.subscriptionId):$($subid.name), please check if you have contributor permission to the resource."  "Red"
    }
    else {
        Write-UTCLog "(Success) Save configuration from subscription $($subid.subscriptionId):$($subid.name)" "Green"
        $json = $jsonresult.value | ConvertTo-Json -Depth 100 | convertfrom-json 
        foreach ($deployment in $json) {
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

# Output to json file
$json_all | ConvertTo-Json -Depth 100 | Out-File $configFile
Write-UTCLog "azureai-config.json is created at $configFile" "Green"
Write-UTCLog "Use '.\invoke-azureai-gpt -listconfig' to see sample " "Green"


