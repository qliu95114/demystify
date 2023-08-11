<#
Author: qliu@microsoft.com ;
Usage: get-azurepublicipaddressrange.ps1 -ipaddr x.x.x.x (public vip address) or -dnsname www.windowsazure.cn

change history
# 5:41 PM 2020-10-10, Added a failfast for unresolvable DNS names
# 5:03 PM 2020-10-10, for now, check if an IP from the list is IPv6 as it throws off parsing. Goal is to eventually parse IPv6
# 11:17 AM 2020-06-25 remove DDOS Jarivs / ACISCLIENT function to get-slb.ps1 , so this version can shared with customer, if needed. 
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

Function Write-console ([string]$message,[string]$color)
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

#get Azure IP Ranges (XML) file from internet
If ((Test-Path "$($env:temp)\publicips.xml") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=41653" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links | where-Object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\publicips.xml"
	$msg="Download "+($FirstPage.Links | where-Object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
}
If ((Test-Path "$($env:temp)\mooncakeips.xml") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=42064" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\mooncakeips.xml"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
}

If ((Test-Path "$($env:temp)\blackforestips.xml") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=54770" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\blackforestips.xml"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
}

#get Azure IP Ranges and Service Tags (JSON) from Internet
If ((Test-Path "$($env:temp)\publicips.json") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\publicips.json"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
}

If ((Test-Path "$($env:temp)\mooncakeips.json") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57062" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\mooncakeips.json"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
}

If ((Test-Path "$($env:temp)\fairfaxips.json") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57063" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\fairfaxips.json"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
}

If ((Test-Path "$($env:temp)\blackforestips.json") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=57064" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\blackforestips.json"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
}

If ((Test-Path "$($env:temp)\wnspublicips.xml") -eq $false)
{
    $FirstPage=Invoke-WebRequest -Uri "https://www.microsoft.com/en-us/download/confirmation.aspx?id=44238" -Method Get -UseBasicParsing
	Invoke-WebRequest -Uri ($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0] -OutFile "$($env:temp)\wnspublicips.xml"
	$msg="Download "+($FirstPage.Links |where-object {$_.outerhtml -like "*Click here*"}).href[0]
	Write-Console $msg "Green"
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
		Write-Console $msg "Green"
	}
}

# Windows Notification service ip https://www.microsoft.com/en-us/download/confirmation.aspx?id=44238

# Do not USE, this is out of date office 365 ip address https://support.content.office.net/en-us/static/O365IPAddresses.xml

[xml]$public=get-content "$($env:temp)\publicips.xml"
[xml]$mooncake=get-content "$($env:temp)\mooncakeips.xml"
[xml]$blackforest=get-content "$($env:temp)\blackforestips.xml"

$public2=(get-content "$($env:temp)\publicips.json")|ConvertFrom-Json
$mooncake2=(get-content "$($env:temp)\mooncakeips.json")|ConvertFrom-Json
$blackforest2=(get-content "$($env:temp)\blackforestips.json")|ConvertFrom-Json
$fairfax2=(get-content "$($env:temp)\fairfaxips.json")|ConvertFrom-Json

if (($ipaddr -eq "") -xor ($dnsname -eq ""))
{
	$inRegion=""
	$inServiceTag=""
	$result=$false
	
	if ($dnsname -ne "") 
	{
		$result = (Resolve-DnsName $dnsname -ErrorAction SilentlyContinue)
		if($null -eq $result) {
			Write-Console "Could not resolve '$($dnsname)' to an IPv4 address" "Red"
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
			Write-Console $dnsname" ["$ipaddr"] belongs to [xml] "$inRegion" | "$subnet  "green"
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
				Write-Console $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"				
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
				Write-Console $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"	

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
				Write-Console $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"				
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
				Write-Console $dnsname" ["$ipaddr"] belongs to [json] "$inSeriveTagName" | "$inServiceTag" | "$inServiceTagRegion" | "$addressprefix  "green"				
			}
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
					Write-Console "$($dnsname) [$($ipaddr)] belongs to [$($o365.name)] |ServiceArea:$($serviceArea) |DisplayName: $($DisplayName) |Port: $($tcpport) |ExR:$($expresroute) |Category:$($category)|Required:$($required)"  "green"				
				}
			}
		}
	}


	if ($result)
	{

	}
	else {
		Write-Console "$($dnsname) [$($ipaddr)] does not belong to Azure public/china/usgov or Office365 public/china/usgov/usgovgcc!" "yellow"
	}

}
else 
{
		Write-Console "[HELP], parameter needed -dnsname or -ipaddr" "yellow"
}