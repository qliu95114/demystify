<#
Author: qliu@microsoft.com ;
Usage: get-azurepublicipaddressrange.ps1 -ipaddr x.x.x.x (public vip address) or -dnsname www.windowsazure.cn

change history
# 10:42 PM 2023-08-11, add Office 365 iprange search
# 5:41 PM 2020-10-10, Added a failfast for unresolvable DNS names
# 5:03 PM 2020-10-10, for now, check if an IP from the list is IPv6 as it throws off parsing. Goal is to eventually parse IPv6
# 1:10 PM 08/12/2018, add Azure IP Ranges and Service Tags (JSON） check, it scans azure service tag file to get more details. 
# 2:23 PM 01/02/2017, auto download the latest Windows Azure Datacenter IP Ranges (public & mooncake)
# demo

.\get-AzurePublicIpAddressRange.ps1 -dnsname portal.azure.com 
[2019-10-27 13:35:55],portal.azure.com [52.231.201.206] belongs to koreasouth | 52.231.128.0/17
[2019-10-27 13:35:57],portal.azure.com [52.231.201.206] belongs to AzureCloud.koreasouth |  | koreasouth | 52.231.128.0/17
[2019-10-27 13:35:57],portal.azure.com [52.231.201.206] belongs to AzureCloud |  |  | 52.231.128.0/17

#>

Param (
    [ValidateScript({$_ -match [IPAddress]$_ })]
    [string]$ipaddr,
	[string]$dnsname
)

Function Write-UTCLog ([string]$message,[string]$color)
{
    	$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
    	$logstamp = "["+$logdate + "]," + $message
        Write-Host $logstamp -ForegroundColor $color
}

function checkSubnet ([string]$cidr, [string]$ip)
{
	$network, [int]$subnetlen = $cidr.Split('/')
	[System.Net.IPAddress]$test = $null
	$ipv6 = [System.Net.Sockets.AddressFamily]::InterNetworkV6
	# TODO: Add support for IPv6, for now skipping
	if(-not [System.Net.IPAddress]::TryParse($network, [ref] $test) -or ($test.AddressFamily -eq $ipv6)) {
		$false
		return
	}
	$a = [uint32[]]$network.split('.')
	[uint32] $unetwork = ($a[0] -shl 24) + ($a[1] -shl 16) + ($a[2] -shl 8) + $a[3]

	$mask = (-bnot [uint32]0) -shl (32 - $subnetlen)

	$a = [uint32[]]$ip.split('.')
	[uint32] $uip = ($a[0] -shl 24) + ($a[1] -shl 16) + ($a[2] -shl 8) + $a[3]

	$unetwork -eq ($mask -band $uip)
}

#get Azure IP Ranges (XML) file from internet this is completedly offline per 2024.12 remove it
if ((Test-Path $env:temp"\publicips.xml") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=41653' -Method Get -UseBasicParsing
	$msg="Download "+($FirstPage.Links | where-object {$_.outerhtml -like "*PublicIPs*"})[0].href
	Write-UTCLog $msg "Green"
	Invoke-WebRequest -Uri ($FirstPage.Links | where-object {$_.outerhtml -like "*PublicIPs*"})[0].href -OutFile $env:temp"\publicips.xml"
}
If ((Test-Path $env:temp"\mooncakeips.xml") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=42064' -Method Get -UseBasicParsing
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*PublicIPs_MC*"})[0].href
	Write-UTCLog $msg "Green"
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*PublicIPs_MC*"})[0].href -OutFile $env:temp"\mooncakeips.xml"
}

If ((Test-Path $env:temp"\blackforestips.xml") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=54770' -Method Get -UseBasicParsing
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*PublicIPs_BF*"})[0].href
	Write-UTCLog $msg "Green"
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*PublicIPs_BF*"})[0].href -OutFile $env:temp"\blackforestips.xml"
}

#get Azure IP Ranges and Service Tags (JSON) from Internet and use original file name
    $FirstPage=Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=56519' -Method Get -UseBasicParsing
	$FileName=($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_Public*"})[0].href.split('/')[8]
	if (Test-Path "$($env:temp)\$($FileName)") {}
	else {
		$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*ServiceTags_Public*"})[0].href
		Write-UTCLog  $msg "Green"
		If ((Test-Path "$($env:temp)\$($FileName)") -eq $true) { Remove-Item "$($env:temp)\$($FileName)" -Force}
		Invoke-WebRequest -Uri ($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_Public*"})[0].href -OutFile "$($env:temp)\$($FileName)"
	}

	$FirstPage=Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=57062' -Method Get -UseBasicParsing
	$FileName=($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_China*"})[0].href.split('/')[8]
	if (Test-Path "$($env:temp)\$($FileName)") {}
	else {
		$msg="Download "+($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_China*"})[0].href
		Write-UTCLog  $msg "Green"
		If ((Test-Path "$($env:temp)\$($FileName)") -eq $true) { Remove-Item "$($env:temp)\$($FileName)" -Force}
		Invoke-WebRequest -Uri ($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_China*"})[0].href -OutFile "$($env:temp)\$($FileName)"
	}

    $FirstPage=Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=57063' -Method Get -UseBasicParsing
	$FileName=($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_AzureGovernment*"})[0].href.split('/')[8]
	if (Test-Path "$($env:temp)\$($FileName)") {}
	else {
		$msg="Download "+($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_AzureGovernment*"})[0].href
		Write-UTCLog  $msg "Green"
		If ((Test-Path "$($env:temp)\$($FileName)") -eq $true) { Remove-Item "$($env:temp)\$($FileName)" -Force}
		Invoke-WebRequest -Uri ($firstpage.links| where-object {$_.outerhtml -like "*ServiceTags_AzureGovernment*"})[0].href -OutFile "$($env:temp)\$($FileName)"
	}
	
    $FirstPage=Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=57064' -Method Get -UseBasicParsing
	$FileName=($FirstPage.Links | where-object {$_.outerhtml -like "*ServiceTags_AzureGermany*"})[0].href.split('/')[8]
	if (Test-Path "$($env:temp)\$($FileName)") {}
	else {
		$msg="Download "+($FirstPage.Links | where-object {$_.outerhtml -like "*ServiceTags_AzureGermany*"})[0].href
		Write-UTCLog  $msg "Green"
		If ((Test-Path "$($env:temp)\$($FileName)") -eq $true) { Remove-Item "$($env:temp)\$($FileName)" -Force}
		Invoke-WebRequest -Uri ($FirstPage.Links | where-object {$_.outerhtml -like "*ServiceTags_AzureGermany*"})[0].href -OutFile "$($env:temp)\$($FileName)"
	}

<#If ((Test-Path "$($env:temp)\wnspublicips.xml") -eq $false)  # this is gone
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=44238" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\wnspublicips.xml"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-UTCLog $msg "Green"
}#>

# need get BYOIP-geoloc.csv and geoloc-Microsoft.csv from https://www.microsoft.com/en-us/download/details.aspx?id=53601
# use iwr to download the file, save content to $env:temp
# "https:\/\/download.microsoft.com\/download\/[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\/BYOIP-geoloc.csv"
# "https:\/\/download.microsoft.com\/download\/[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\/geoloc-Microsoft.csv"

#https://download.microsoft.com/download/0b9dc6ca-68f9-43b2-b094-da4f6d509bc3/BYOIP-geoloc.csv
#https://download.microsoft.com/download/0b9dc6ca-68f9-43b2-b094-da4f6d509bc3/geoloc-Microsoft.csv

# Get the raw content of the download page and search for URLs using regex
$webContent = Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/details.aspx?id=53601" -UseBasicParsing
$rawContent = $webContent.RawContent

# Define regex patterns
$byoipPattern = "https:\/\/download.microsoft.com\/download\/[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\/BYOIP-geoloc.csv"
$geolocPattern = "https:\/\/download.microsoft.com\/download\/[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}\/geoloc-Microsoft.csv"

# Extract URLs using regex
$byoipUrl = [regex]::Match($rawContent, $byoipPattern).Value
$geolocUrl = [regex]::Match($rawContent, $geolocPattern).Value

If ((Test-Path "$($env:temp)\$($geolocUrl.Split('/')[-1])") -eq $false)
{
	Invoke-WebRequest -Uri $byoipUrl -OutFile "$($env:temp)\$($geolocUrl.Split('/')[-1])" 
	Write-UTCLog "Downloaded $($geolocUrl)" "Green"
}

If ((Test-Path "$($env:temp)\$($byoipUrl.Split('/')[-1])") -eq $false)
{
	Invoke-WebRequest -Uri $byoipUrl -OutFile "$($env:temp)\$($byoipUrl.Split('/')[-1])" 
	Write-UTCLog "Downloaded $($byoipUrl)" "Green"
}

# create array $officeurl for office 365 ip address 
$officeurl=@("https://endpoints.office.com/endpoints/worldwide?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7",
"https://endpoints.office.com/endpoints/China?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7",
"https://endpoints.office.com/endpoints/USGOVDoD?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7",
"https://endpoints.office.com/endpoints/USGOVGCCHigh?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7")

# download url from $officeurl array
foreach ($url in $officeurl)
{
	$filename=$url.split("/")[-1].split("?")[0]
	if ((Test-Path "$($env:temp)\o365_$($filename).json") -eq $false)
	{
		Invoke-WebRequest -Uri $url -OutFile "$($env:temp)\o365_$($filename).json"
		$msg="Download $($url) ..."
		Write-UTCLog $msg "Green"
	}
}

# Windows Notification service ip https://www.microsoft.com/en-us/download/confirmation.aspx?id=44238

# Do not USE, this is out of date office 365 ip address https://support.content.office.net/en-us/static/O365IPAddresses.xml

[xml]$public=get-content "$($env:temp)\publicips.xml"
[xml]$mooncake=get-content "$($env:temp)\mooncakeips.xml"
[xml]$blackforest=get-content "$($env:temp)\blackforestips.xml"

$public2=get-content (Get-ChildItem -Path "$($env:temp)\ServiceTags_Public*.json" |  Sort-Object LastWriteTime -Descending | Select-Object -First 1)|ConvertFrom-Json
$mooncake2=get-content (Get-ChildItem -Path "$($env:temp)\ServiceTags_China*.json" |  Sort-Object LastWriteTime -Descending | Select-Object -First 1)|ConvertFrom-Json
$blackforest2=get-content (Get-ChildItem -Path "$($env:temp)\ServiceTags_AzureGovernment*.json" |  Sort-Object LastWriteTime -Descending | Select-Object -First 1)|ConvertFrom-Json
$fairfax2=get-content (Get-ChildItem -Path "$($env:temp)\ServiceTags_AzureGermany*.json" |  Sort-Object LastWriteTime -Descending | Select-Object -First 1)|ConvertFrom-Json

$byoipgeoloc=Import-csv "$env:temp\BYOIP-geoloc.csv"
$geolocmicrosoft=Import-csv "$env:temp\geoloc-Microsoft.csv"

if (($ipaddr -eq "") -xor ($dnsname -eq ""))
{
	$inRegion=""
	$inServiceTag=""
	$result=$false
	
	if ($dnsname -ne "") 
	{
		$result = (Resolve-DnsName $dnsname -ErrorAction SilentlyContinue)
		if($null -eq $result) {
			Write-UTCLog "Could not resolve '$($dnsname)' to an IPv4 address" "Red"
			return
		}
		$ipaddr=$result.ip4address
	}
	
	#check if ip belongs to azure public 
	foreach ($region in $public.AzurePublicIpAddresses.Region)
		{
			foreach ($range in $region.iprange)
			{
				#$range.subnet
				if (checkSubnet $range.subnet $ipaddr) 
				{
					#write-output $region.name 
					$inRegion=$region.name
					$subnet=$range.subnet
					$setenv="prod"
					break
				}
			}
			if ($inRegion -ne "") {break}  
		}
	
	#check if ip belongs to azure mooncake
	foreach ($region in $mooncake.AzurePublicIpAddresses.Region)
		{
			foreach ($range in $region.iprange)
			{
				#$range.subnet
				if (checkSubnet $range.subnet $ipaddr) 
				{
					#write-output $region.name 
					$inRegion=$region.name
					$subnet=$range.subnet					
					$setenv="mc"					
					break
				}
			}
			if ($inRegion -ne "") {break}  
		}
	
	#check if ip belongs to azure blackforest
	foreach ($region in $blackforest.AzurePublicIpAddresses.Region)
		{
			foreach ($range in $region.iprange)
			{
				#$range.subnet
				if (checkSubnet $range.subnet $ipaddr) 
				{
					#write-output $region.name 
					$inRegion=$region.name
					$subnet=$range.subnet			
					$setenv="bf"		
					break
				}
			}
			if ($inRegion -ne "") {break}  
		}

	If ($inRegion -ne "")  
	{
			$result=$true
			Write-UTCLog $dnsname" ["$ipaddr"] belongs to [xml] "$inRegion" | "$subnet  "green"
	}

	#here start with JSON search with service TAG details - public azure
	foreach ($ServiceTag in $public2.values)
	{
		foreach ($addressprefix in $ServiceTag.properties.addressPrefixes)
		{
			if (checkSubnet $addressprefix $ipaddr) 
			{
				$inSeriveTagName=$ServiceTag.name
				$inServiceTag=$ServiceTag.properties.systemService
				$inServiceTagRegion=$ServiceTag.properties.region
				$result=$true
				$setenv="prod"
				Write-UTCLog $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"				
			}
		}
	}

    #here start with JSON search with service TAG details - Mooncake
	foreach ($ServiceTag in $mooncake2.values)
	{
		foreach ($addressprefix in $ServiceTag.properties.addressPrefixes)
		{
			if (checkSubnet $addressprefix $ipaddr) 
			{
				$inSeriveTagName=$ServiceTag.name
				$inServiceTag=$ServiceTag.properties.systemService
				$inServiceTagRegion=$ServiceTag.properties.region
				$result=$true
				$setenv="mc"
				Write-UTCLog $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"	

			}
		}
	}

	#here start with JSON search with service TAG details - Fairfax
	foreach ($ServiceTag in $fairfax2.values)
	{
		foreach ($addressprefix in $ServiceTag.properties.addressPrefixes)
		{
			if (checkSubnet $addressprefix $ipaddr) 
			{
				$inSeriveTagName=$ServiceTag.name
				$inServiceTag=$ServiceTag.properties.systemService
				$inServiceTagRegion=$ServiceTag.properties.region
				$result=$true
				$setenv="ff"
				Write-UTCLog $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"				
			}
		}
	}	

	#here start with JSON search with service TAG details - blackforest
	foreach ($ServiceTag in $blackforest2.values)
	{
		foreach ($addressprefix in $ServiceTag.properties.addressPrefixes)
		{
			if (checkSubnet $addressprefix $ipaddr) 
			{
				$inSeriveTagName=$ServiceTag.name
				$inServiceTag=$ServiceTag.properties.systemService
				$inServiceTagRegion=$ServiceTag.properties.region
				$result=$true
				$setenv="bf"
				Write-UTCLog $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"				
			}
		}
	}

	#here start with CSV for geolocmicrosoft
	foreach ($geoloc in $geolocmicrosoft)
	{
		if (checkSubnet $geoloc."IP Range" $ipaddr) 
		{
			$inSeriveTagName=$geoloc."IP Range"
			$inCountry=$geoloc.Country
			$inRegion=$geoloc.Region
			$inCity=$geoloc.City
			$inPostalCode=$geoloc."Postal Code"
			$result=$true
			Write-UTCLog $dnsname" ["$ipaddr"] belongs to [Microsoft GEO LOC] "$inSeriveTagName" | "$inCountry" | "$inRegion" | "$inCity" | "$inPostalCode  "green"
		}
	}


	#here start with CSV for byoipgeoloc
	foreach ($byoip in $byoipgeoloc)
	{
		if (checkSubnet $byoip."IP Range" $ipaddr) 
		{
			$inSeriveTagName=$byoip."IP Range"
			$inCountry=$byoip.Country
			$inRegion=$byoip.Region
			$inCity=$byoip.City
			$inPostalCode=$byoip."Postal Code"
			$result=$true
			Write-UTCLog $dnsname" ["$ipaddr"] belongs to [Bring Your Own IP GEO LOC] "$inSeriveTagName" | "$inCountry" | "$inRegion" | "$inCity" | "$inPostalCode  "green"
		}
	}


	#here start with JSON search with office 365 details
	$o365jsonfiles=Get-ChildItem "$($env:temp)\o365_*.json"
	foreach ($o365 in $o365jsonfiles)
	{
		$o365json=(get-content $o365)|ConvertFrom-Json
		foreach ($service in $o365json)
		{
			foreach ($addressprefix in $service.ips)
			{
				if (checkSubnet $addressprefix $ipaddr) 
				{
					$serviceArea = $service.serviceArea
					$DisplayName = $service.serviceAreaDisplayName
					$tcpport = $service.tcpPorts
					$expresroute = $service.expressRoute
					$category = $service.category
					$required = $service.required
					$result=$true
					Write-UTCLog "$($dnsname) [$($ipaddr)] belongs to [$($o365.name)] |ServiceArea:$($serviceArea) |DisplayName: $($DisplayName) |Port: $($tcpport) |ExR:$($expresroute) |Category:$($category)|Required:$($required)"  "green"				
				}
			}
		}
	}


	if ($result)
	{

	}
	else {
		Write-UTCLog "$($dnsname) [$($ipaddr)] does not belong to Azure public/china/usgov or Office365 public/china/usgov/usgovgcc!" "yellow"
	}

}
else 
{
		Write-UTCLog "[HELP], parameter needed -dnsname or -ipaddr" "yellow"
}
