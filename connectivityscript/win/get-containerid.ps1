# this script will get Azure Container Id 
# help me explain this script
# 1. get the xml file from Azure VM
# 2. get the container id from xml file
# 3. print the container id
# 4. you can use this script to get the container id from Azure VM

# author : qliu
# time : 2023-06-23

([xml](c:\windows\system32\curl "http://168.63.129.16/machine?comp=goalstate" -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A """")).GoalState.Container| Format-list