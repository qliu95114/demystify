# This the powershell script that take few parameters: location (optional) and subscriptionId (optional) and vmsize (required)
param(
    [string]$location,
    [string]$subscriptionId,
    [string]$vmsize,
    [switch]$showall
)

# if subscriptionId is null, check current context and ask user if this is the subid we and to check if user provide a new subid, switch to that subid
if ($subscriptionId) {
    Write-Host "Switching to Subscription ID: $subscriptionId"
    Connect-AzAccount -SubscriptionId $subscriptionId

} else {
    $currentContext = Get-AzContext 
    Write-Host "Current Subscription ID: $($currentContext.Subscription.Id) , Name: $($currentContext.Subscription.Name)"
    $userInput = Read-Host "Do you want to use this subscription? (Y/N)"
    if ($userInput -ne 'Y' -and $userInput -ne 'y') {
        $newSubId = Read-Host "Please enter the Subscription ID you want to switch to"
        Connect-AzAccount -SubscriptionId $newSubId
    }
}

# Get the current subscription context
$currentContext = Get-AzContext 
$currentSubscriptionId = $currentContext.Subscription.Id
Write-Host "Using Subscription ID: $currentSubscriptionId" -ForegroundColor Cyan
Write-Host "Using Subscription Name: $($currentContext.Subscription.Name)" -ForegroundColor Cyan

# if location is not provided, use all location
if (-not $location) {
    $locations = (Get-AzLocation).Location
} else {
    $locations = @($location)
    Write-Host "Checking only location: $location"  -ForegroundColor Cyan
}

if ($showall -or $location)    {
}
else {
    Write-host "-showall not specified, only locations that support the VM size will be shown." -ForegroundColor Yellow
}

foreach ($loc in $locations) {
   # Check the quota for the specified VM size
   if (-not $vmsize) {
        $quota = Get-AzComputeResourceSku -Location $loc |Where-Object {  $_.ResourceType -eq "virtualMachines"} 
        $quota.count
   }
   else {
        $quota = Get-AzComputeResourceSku -Location $loc |Where-Object {  $_.ResourceType -eq "virtualMachines"}| Where-Object { $_.name -like "*$($vmsize)*" } 
   }
   

   # if no quota found, write message and continue to next location
   if (-not $quota) {
        if ($showall) {Write-Host "'$loc' : does not support VM sizes '$vmsize'" -ForegroundColor "Yellow"} # do not show this message unless showall is specified
        continue
   }
   else {
       foreach ($q in $quota) {
        # if $q.restrictions is empty, then no restrictions
        if (-not $q.Restrictions) {

            Write-Host "Checking VM size $($q.name) availability and quota in location '$loc'..." -ForegroundColor Cyan            
            # calculate and vm family name based on $q.name and verify quota for that vm family
            $i=$q.name.split('_').count
            $vmfamily = ""
            for ($j=1; $j -lt $i; $j++) {
                    if ($j -eq 1) 
                    {
                        $vmfamily = $($q.name.split('_')[$j] -replace '\d+','')
                    }
                    else {
                        $vmfamily = $vmfamily +$q.name.split('_')[$j]
                    }
            }

            $hasquota = $true            
            # check quota for location, cores , virtualMachines and vmfamily
            try 
            {
                $quotaDetails = Get-AzVMUsage -Location $loc | Where-Object { ($_.Name.Value -eq "cores") -or ($_.Name.Value -eq "virtualMachines") -or ($_.Name.LocalizedValue -like "* $($vmfamily) *") }
                foreach ($quotaDetail in $quotaDetails) {
                    # if limit = currntvalue, write warning
                    if ($quotaDetail.CurrentValue -ge $quotaDetail.Limit) {
                        Write-Host "    Current Usage: $($quotaDetail.CurrentValue), Limit: $($quotaDetail.Limit) - $($quotaDetail.Name.LocalizedValue) " -ForegroundColor "Yellow"
                        $hasquota = $false
                    }
                    else {
                        Write-Host "    Current Usage: $($quotaDetail.CurrentValue), Limit: $($quotaDetail.Limit) - $($quotaDetail.Name.LocalizedValue) " -ForegroundColor "Green"
                    }
                }
            }
            catch 
            {
                Write-Host "    Unable to retrieve quota details for location '$loc'. assume we have quota" -ForegroundColor "Red"
                $hasquota = $true            
            }

            if ($hasquota) {
                Write-Host "'$loc' summary: support VM Size: $($q.Name), No restrictions found, quota available." -ForegroundColor "Green"            
            }
            else {
                Write-Host "'$loc' summary: support VM Size: $($q.Name), No restrictions found, but quota limits reached." -ForegroundColor "Yellow"            
            }
            Write-Host "-------------------------"            
        }
        else {
            # if restrictions found, write them 
            if ($showall -or (-not $vmsize))   {
                Write-Host "'$loc' : support VM Size: $($q.Name), Restrictions: $($q.RestrictionInfo)" -ForegroundColor "Yellow"
                foreach ($restriction in $q.Restrictions) {
                    Write-Host "    Type: $($restriction.Type), Reason Code: $($restriction.ReasonCode)" -ForegroundColor "Red"

            }
        }
        }
    }
   }
}