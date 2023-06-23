# this script will get Azure Container Id 
# help me explain this script
# 1. get the xml file from Azure VM
# 2. get the container id from xml file
# 3. print the container id
# 4. you can use this script to get the container id from Azure VM

# To use the script
# a. Open Azure VM
# b. Open Powershell
# c. Run 
#     iex (new-object net.webclient).downloadstring("https://aka.ms/getcid")
#     iex (new-object net.webclient).downloadstring("https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/win/get-containerid.ps1")
# d. you will get the container id  

# author : qliu
# time : 2023-06-23

$containerid=([xml](c:\windows\system32\curl "http://168.63.129.16/machine?comp=goalstate" -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A """")).GoalState.Container.ContainerId
$InstanceId=([xml](c:\windows\system32\curl "http://168.63.129.16/machine?comp=goalstate" -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A """")).GoalState.Container.RoleInstanceList.RoleInstance.InstanceId

$logdate = ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "[$($logdate)],HostName: $env:computername" -ForegroundColor Cyan
Write-Host "[$($logdate)],ContainerId: $containerid" -ForegroundColor Cyan
Write-Host "[$($logdate)],InstanceId: $InstanceId" -ForegroundColor Cyan
