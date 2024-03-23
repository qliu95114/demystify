# this script use az cli command list azure subscription for all NotRegistered feature to csv file and then register all of them 

# parameter is the subscription id and this is mandatory
param(
    [Parameter(Mandatory=$true)][string]$subscriptionId
)

Function Write-UTCLog ([string]$message,[string]$color="Green")
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

# check if we have active login
$accounts=(az account list)|ConvertFrom-json
if($accounts.Length -eq 0){
    Write-UTCLog "No active login, run az login first" "Red"
    az login
}

$matched = $false
# go through $account and see if any subscription match $subscriptionid
foreach ($sub in $accounts){
    if ($sub.id -eq $subscriptionId){
        $matched = $true
        Write-UTCLog "We have subscription match, setting subscription to $subscriptionId, retrieving all NotRegistered features to $($env:temp)\$($subscriptionId)_NotRegisteredFeatures.csv" "Green"
        # set subscription
        az account set --subscription $subscriptionId
        # list all NotRegistered feature to csv file
        az feature list --query "[?properties.state=='NotRegistered']" --output table > "$($env:temp)\$($subscriptionId)_NotRegisteredFeatures.csv"
        $Features=Get-Content "$($env:temp)\$($subscriptionId)_NotRegisteredFeatures.csv" | Select-Object -Skip 2
        $total=$Features.count
        $i=1
        foreach ($feature in $Features){
            $featurename=$feature.Split("/")[1]
            $providername=$feature.Split("/")[0]
            #only $featurename and $providername both not empty go to register
            if ([string]::IsNullOrEmpty($featurename) -or [string]::IsNullOrEmpty($providername)){
            }
            else {
                Write-UTCLog "($($i)/$($total))Registering ($($providername)) $($featurename)" "Yellow"
                az feature register --namespace $providername --name $featurename | Out-File -Append "$($env:temp)\$($subscriptionId)_RegisterFeature.log" -Encoding utf8
            }
            $i++
        }
        break
    }
}

if ($matched -eq $false){
    Write-UTCLog "No subscription match, please check your login that can access the subid: $($subscriptionid)" "Red"
    exit
}

#invoking 'az provider register -n Microsoft.eventgrid' is required to get the change propagated






