#!/bin/bash

# Name 
# test_dns - This script will run ping test, save result to logfile and send result to Application Insight (via instrumentation key)

# SYNOPSIS
# bash test_dns.sh  [dnsname] [aikey or (0||empty)] [dnsserver ip address] [logfile]

# Options: 
# $1 : FQDN Name 
# $2 : Application Insight instrumentation key (aikey, 48 Guid) , 0 or leave empty will skip send-aievent()
# $3 ：IP Address of Dns Server
# $4 : Logfile, include path and file name

# Examples:
# test_dns www.bing.com, save result to default logfile /tmp/$(hostname -s)_test_dns_sh_${ipaddr}.log.
# ./test_dns.sh www.bing.com 

# Ping 8.8.4.4, save result to default log /tmp/$(hostname -s)_test_dns_sh_${ipaddr}.log., and use 168.63.129.16 (Azure VM default DNS SERVER)
# ./test_dns.sh www.bing.com 0 168.63.129.16

# Ping 8.8.4.4, save result to default log /tmp/$(hostname -s)_test_dns_sh_${ipaddr}.log., and use 168.63.129.16 (Azure VM default DNS SERVER) and send result to Application Insight 
# ./test_dns.sh www.bing.com 11111111-1111-1111-1111-111111111111 168.63.129.16

# Ping 8.8.4.4, save result to /tmp/mydns.log use 168.63.129.16 (Azure VM default DNS SERVER and send result to Application Insight 
# ./test_dns.sh www.bing.com 11111111-1111-1111-1111-111111111111 /tmp/mydns.log

# Author: Qing Liu
# nslookup -timeout=1 -retry=1 -type=A www.google.com. 10.10.10.10 | awk '!a[$0]++' | tr '\n' ';' | tr '\t' ' '

# Print string with UTC time and color
function write-utclog() {
  # Get current UTC time
  utc_time=$(date -u +"%Y-%m-%d %H:%M:%S.%3N")
  
  case $2 in
    red) color='\033[0;31m' ;;
    green) color='\033[0;32m' ;;
    yellow) color='\033[1;33m' ;;
    blue) color='\033[0;34m' ;;
    magenta) color='\033[0;35m' ;;
    cyan) color='\033[0;36m' ;;
    *) color='\033[0m' ;;
  esac

  # Print string with UTC time and color
  echo -e "${color}[${utc_time}],$1${reset}"
}

#Tested TAG
#AI Customer Event Field = Tags : explanation  
#client_Type = ai.device.type: the type of the device
#client_OS = ai.device.osVersion: the version of the operating system of the device
#client_Model = ai.device.model: the model of the device
#client_RoleInstance = ai.cloud.roleInstance: the name of the cloud role instance
#user_Id = ai.user.id: the user identifier

#Untested TAG
#ai.application.ver: the version of the application
#ai.cloud.role: the name of the cloud role instance
#ai.cloud.roleName: the name of the cloud role
#ai.device.id: a unique identifier for the device
#ai.device.locale: the locale of the device
#ai.device.oemName: the name of the original equipment manufacturer of the device
#ai.device.os: the operating system of the device
#ai.internal.sdkVersion: the version of the Application Insights SDK
#ai.operation.id: a unique identifier for the operation
#ai.operation.name: the name of the operation
#ai.operation.parentId: the identifier of the parent operation
#ai.operation.syntheticSource: the source of the synthetic operation
#ai.session.id: a unique identifier for the session
#ai.session.isFirst: a boolean indicating whether this is the first session for the user
#ai.user.accountId: the identifier of the user account
#ai.user.anonId: a unique identifier for the user
#ai.user.userAgent: the user agent string of the client making the request

# Send Customer Event via POST call to Application Insights. 
function send-aievent {
  if [[ "$1" = "0" || -z "$1" ]]
  then 
    echo "Info : Aikey is 0 or Not Specified, send-aievent() is skipped." 
  else
    cname=$(hostname -s)
    uname=$(id -un)
    clientos=$(cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g')
    clientmodel=$(uname -r)
    #clientip=$(ip addr show dev eth0 | grep 'inet '|awk '{print $2}'|awk -F '/' '{print $1}')
    aikey=$1; message=$2; dnsname=$3; dnsserver=$4; name=$5
    utc_time=$(date -u +"%Y-%m-%d %H:%M:%S.%3N")    
    telemetry='{
                "name":"Microsoft.ApplicationInsights.'${aikey}'.Event",
                "time":"'${utc_time}'",
                "iKey":"'${aikey}'",
                "tags":{
                    "ai.cloud.roleInstance":"'${cname}'",
                    "ai.user.id":"'${uname}'",
                    "ai.device.osVersion":"'${clientos}'",
                    "ai.device.model":"'${clientmodel}'"
                  },
                "data":{
                    "baseType":"EventData",
                    "baseData":
                      {
                          "ver":2,
                          "name":"'${name}'",
                          "properties":
                            {
                              "message":"'${message}'",
                              "dnsname":"'${dnsname}'",
                              "dnsserver":"'${dnsserver}'"
                            }
                      }
                  }
               }'
    #echo ${telemetry}
    curl --connect-timeout 3.0 --retry 4 --retry-delay 1 -X POST -H "Content-Type: application/x-json-stream"  -d "$telemetry" "https://dc.services.visualstudio.com/v2/track" -o /dev/null -s &
    echo "Info : aikey is specified, send-aievent() is called"    
  fi
}

# main routing 
#1 is target ip address or fqdn dns name
if [ -z "$1" ] 
then
  read -p "Enter your target dns name (e.g. dns.google):" dnsname
else
  dnsname=$1
fi

#3 is dns server
if [ -z "$3" ] 
then
  write-utclog "dnsserver is not specified, use system default dns" "cyan"
else
  dnsserver=$3
fi

#4 is logfile
if [ -z "$4" ]
then
  logfile="/tmp/$(hostname -s)_test_dns_sh_${dnsname}.log"
else
  logfile=$3
fi

#2 is instrumentation key
if [ -z "$2" ]
then
  ikey="0"
else
  ikey=$2  
  send-aievent "${ikey}" "test_dns_sh started, logfile: ${logfile}" "${dnsname}" "${dnsserver}" "test_dns_sh"
fi

write-utclog "target dns : ${dnsname}" "cyan"
write-utclog "log file : ${logfile}"  "cyan"

# main function of nslookup
while true
do
  result=$(nslookup -timeout=2 -retry=1 -type=A ${dnsname}. ${dnsserver} | awk '!a[$0]++' | tr '\n' '|' | tr '\t' ' ')  # remove duplicate line, remove \n and \t for JSON format
  echo "$(date -u +'%F %H:%M:%S.%3N'),${dnsname}.,${dnsserver},${result}" | tee -a $logfile
  send-aievent "${ikey}" "${result}" "${dnsname}" "${dnsserver}" "test_dns_sh"
  sleep 1 
done

