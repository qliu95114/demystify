#!/bin/bash

# Name 
# test_ping - This script will run ping test, save result to logfile and send result to Application Insight (via instrumentation key)

# SYNOPSIS
# bash test_ping.sh  [ipaddress||dnsname] [aikey or (0||empty)] [logfile]

# Options: 
# $1 : IP Address or FQDN DNS Name
# $2 : Application Insight instrumentation key (aikey, 48 Guid) , 0 or leave empty will skip send-aievent()
# $3 : logfile, include path and file name

# Examples:
# Ping 8.8.4.4, save result to default logfile /tmp/$(hostname -s)_test_ping_sh_${ipaddr}.log.
# ./test_ping.sh 8.8.4.4 

# Ping 8.8.4.4, save result to custom logfile /tmp/myping.log.
# ./test_ping.sh 8.8.4.4 0 /tmp/myping.log

# Ping 8.8.4.4, send result to Application Insight and save result to default logfile /tmp/$(hostname -s)_test_ping_sh_${ipaddr}.log
# ./test_ping.sh 8.8.4.4 11111111-1111-1111-1111-111111111111

# Ping 8.8.4.4, send result to Application Insight and save result to custom logfile /tmp/myping.log.
# ./test_ping.sh 8.8.4.4 11111111-1111-1111-1111-111111111111 /tmp/myping.log

# Author: Qing Liu

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
    aikey=$1; message=$2; target=$3; tid=$4; containerid=$5
    utc_time=$(date -u +"%Y-%m-%d %H:%M:%S.%3N")    
    telemetry='{
                "name":"Microsoft.ApplicationInsights.'${aiKey}'.Event",
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
                          "name":"test_ping_sh",
                          "properties":
                            {
                              "message":"'${message}'",
                              "target":"'${target}'",
                              "tid":"'${tid}'",
                              "cid":"'${containerid}'"
                            }
                      }
                  }
               }'
    curl --connect-timeout 3.0 --retry 4 --retry-delay 1 -X POST -H "Content-Type: application/x-json-stream"  -d "$telemetry" "https://dc.services.visualstudio.com/v2/track" -o /dev/null -s &
    echo "Info : aikey is specified, send-aievent() is called"    
  fi
}

# main routing 
# Creates random 8-bytes characters to track ping thread in Application Insight 
tid=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 ; echo '')  

# azure get containerid from a vm
cid=$(sudo curl -s --connect-timeout 1 http://168.63.129.16/machine?comp=goalstate -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" |sed -n 's:.*<ContainerId>\([^<]*\)</ContainerId>.*:\1:p')

#1 is target ip address or fqdn dns name
if [ -z "$1" ] 
then
  read -p "Enter your target ip address or dns name (e.g. 8.8.8.8 or dns.google):" ipaddr
else
  ipaddr=$1
fi

#3 is logfile
if [ -z "$3" ]
then
  logfile="/tmp/$(hostname -s)_test_ping_sh_${ipaddr}.log"
else
  logfile=$3
fi

#2 is instrumentation key
if [ -z "$2" ]
then
  ikey="0"
else
  ikey=$2  
  send-aievent "${ikey}" "test_ping_sh started, logfile: ${logfile}" "${ipaddr}" "${tid}" "${cid}"
fi

write-utclog "target dns or ip : ${ipaddr}" "cyan"
write-utclog "log file : ${logfile}"  "cyan"

# main function of ping
ping -O $ipaddr -W 1 -i 1 | while read pong; do echo "$(date -u +'%F %H:%M:%S.%3N'),${tid},${pong}"; echo "$(date -u +'%F %H:%M:%S,%3N'),${tid},${pong}" | iconv -t UTF-8 >> $logfile ; send-aievent "${ikey}" "${pong}" "${ipaddr}" "${tid}" "${cid}"; done 2>&1 
