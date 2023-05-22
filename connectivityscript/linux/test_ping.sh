#!/bin/bash

# Name 
# test_ping - This script will run ping test, save result to logfile and send result to Application Insight (via instrumentation key)

# SYNOPSIS
# bash test_ping.sh -ip [ipaddress] -dnsname [dnsname] -aikey [aikey or (0||empty)] -logpath [logpath, default: /tmp/] -interval [seconds: 1 (default)] -timedlog [0 : Disable(default)]

# Options: 
# -ip or -dnsname : IP Address or FQDN DNS Name
# -aikey : Application Insight instrumentation key (aikey, 48 Guid) , 0 or leave empty will skip send-aievent()
# -logpath : where log file to be saved, filename convention: $(hostname -s)_test_ping_sh_${ipaddr}.log
# -interval : ping timeout in seconds, default 1 seconds
# -timedlog : 0: Disable(default), 1: Every Minutes, 2, Every 10 Minutes: 3: Every 1 Hour, 4: Every 1 Day

# Examples:
# Ping 8.8.4.4, save result to default logpath /tmp/$(hostname -s)_test_ping_sh_${ipaddr}.log,  icmp timeout is 3 seconds
# ./test_ping.sh -ip 8.8.4.4 -interval 3

# Ping 8.8.4.4, save result to custom logfile /mnt/$(hostname -s)_test_ping_sh_${ipaddr}.log.
# ./test_ping.sh -ip 8.8.4.4 -logpath /mnt

# Ping 8.8.4.4, send result to Application Insight and save result to default logfile /tmp/$(hostname -s)_test_ping_sh_${ipaddr}.log
# ./test_ping.sh -ip 8.8.4.4 -aikey 11111111-1111-1111-1111-111111111111

# Ping 8.8.4.4, send result to Application Insight and save result to custom logfile /tmp/$(hostname -s)_test_ping_sh_${ipaddr}.log.
# ./test_ping.sh -ip 8.8.4.4 -aikey 11111111-1111-1111-1111-111111111111 -logpath /mnt

# Ping 8.8.4.4, send result to Application Insight and save result to custom logfile /tmp/$(hostname -s)_test_ping_sh_${ipaddr}_%yyyy-mm-dd_hhmm%.log, log interval is 10 minutes. 
# ./test_ping.sh -ip 8.8.4.4 -logpath /mnt -timedlog 2

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
    a="nothing"
  else
    cname=$(hostname -s)
    uname=$(id -un)
    clientos=$(cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g')
    clientmodel=$(uname -r)
    #clientip=$(ip addr show dev eth0 | grep 'inet '|awk '{print $2}'|awk -F '/' '{print $1}')
    aikey=$1; message=$2; target=$3; tid=$4; containerid=$5 ; interval=$6; timedlog=$7
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
                              "cid":"'${containerid}'",
                              "interval":"'${interval}'",
                              "timedlog":"'${timedlog}'"
                            }
                      }
                  }
               }'
    curl --connect-timeout 3.0 --retry 4 --retry-delay 1 -X POST -H "Content-Type: application/x-json-stream"  -d "$telemetry" "https://dc.services.visualstudio.com/v2/track" -o /dev/null -s &
    echo "Info : aikey is specified, send-aievent() is called"    
  fi
}

#appedtimedlog() is used to create log in different time range 
function appendtimedlog
{
  message=$1; logfile=$2; timedlog=$3
  #switch timedlog 0,1,2,3,4 and generate utc_timestamp different 
  case $timedlog in
    1) 
      utc_timestamp=$(date -u +"%Y-%m-%d_%H%M")
      #remove logfile extension .log and add utc_timestamp to the end of logfile and then add .log back
      logfilename=${logfile%.*}_${utc_timestamp}.log
      ;;
    2) 
      utc_timestamp=$(date -u +"%Y-%m-%d_%H%M") 
      utc_timestamp=${utc_timestamp%?}0
      #replace utc_timestamp's last digit with 0 
      logfilename=${logfile%.*}_${utc_timestamp}.log
      ;;
    3) 
      utc_timestamp=$(date -u +"%Y-%m-%d_%H00")
      logfilename=${logfile%.*}_${utc_timestamp}.log 
      ;;
    4) 
      utc_timestamp=$(date -u +"%Y-%m-%d_0000") 
      logfilename=${logfile%.*}_${utc_timestamp}.log
      ;;
    *) 
      logfilename=${logfile}
      ;;
  esac
  # append message to logfile in UTF-8 format
  echo -e "${message}" >> $logfilename
}


# main routing 
# Creates random 8-bytes characters to track ping thread in Application Insight 
tid=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 ; echo '')  

#parse input parameters
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -ip)
      ipaddr="$2"
      shift # past argument
      shift # past value
      ;;
    -logpath)
      logpath="$2"
      shift # past argument
      shift # past value
      ;;
    -aikey)
      ikey="$2"
      shift # past argument
      shift # past value
      ;;
    -dnsname)      
      ipaddr="$2"
      shift # past argument
      shift # past value
      ;;
    -timedlog)      
      timedlog="$2"
      shift # past argument
      shift # past value
      ;;
    -interval)      
      interval="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      echo "invalid option: $key"
      echo "help: -ip [ipaddress] -logpath [logpath] -aikey [aikey] -dnsname [dnsname] -timedlog [timedlog  # 0: Disable, 1: Every Minutes, 2, Every 10 Minutes: 3: Every 1 Hour, 4: Every 1 Day] -interval [seconds]"
      exit 1
      ;;
  esac
done

# azure get containerid from a vm
curl -s --connect-timeout 0.2 http://168.63.129.16/machine?comp=goalstate -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -o /tmp/cid.xml
cid=$(sed -n 's:.*<ContainerId>\([^<]*\)</ContainerId>.*:\1:p' /tmp/cid.xml)

#if ipaddr is empty , we need read from console
if [ -z "$ipaddr" ] 
then
  read -p "Enter your target ip address or dns name (e.g. 8.8.8.8 or dns.google):" ipaddr
fi

# check interval is empty or number or not
if [ -z "$interval" ] || [ "$interval" -eq "0" ]
then
  interval="1"
else
  if ! [[ "$interval" =~ ^[0-9]+$ ]]
  then
    write-utclog "Warning : interval is not a number, set to 1 second" "Yellow"
  fi
fi

#create log file nanme
if [ -z "$logpath" ]
then
  logfile="/tmp/$(hostname -s)_test_ping_sh_${ipaddr}.log"
else
  logfile="/${logpath}/$(hostname -s)_test_ping_sh_${ipaddr}.log"
fi

#check if timedlog is empty
if [ -z "$timedlog" ]
then
  timedlog="0"
  loginterval="None"  
else
  #determine timedlog is 0,1,2,3,4 or not
  if [ "$timedlog" -eq "0" ] || [ "$timedlog" -eq "1" ] || [ "$timedlog" -eq "2" ] || [ "$timedlog" -eq "3" ] || [ "$timedlog" -eq "4" ]
  then
    if [ "$timedlog" -eq "0" ]
    then
      loginterval="None"
    elif [ "$timedlog" -eq "1" ]
    then
      loginterval="Every Minutes"
    elif [ "$timedlog" -eq "2" ]
    then
      loginterval="Every 10 Minutes"
    elif [ "$timedlog" -eq "3" ]
    then
      loginterval="Every 1 Hour"
    elif [ "$timedlog" -eq "4" ]
    then
      loginterval="Every 1 Day"
    fi
  else
    write-utclog "timedlog ${timedlog} is invalid, set to 0" "yellow"
    timedlog="0"
    loginterval="None"
  fi
fi

#check if aikey is empty
if [ -z "$ikey" ]
then
  ikey="0"
  write-utclog "Info : Aikey is 0 or Not Specified, send-aievent() is skipped." "yellow"
else
  send-aievent "${ikey}" "test_ping_sh started, logfile: ${logfile}" "${ipaddr}" "${tid}" "${cid}" "${timedlog}" "${interval}" 
fi

write-utclog "target dns or ip : ${ipaddr}" "cyan"
write-utclog "timed log : ${timedlog} , loginterval : ${loginterval}"  "cyan"
# if timedlog is not 0
if [ "$timedlog" -ne "0" ]
then
  write-utclog "log file : ${logfile%.*}_%yyyy-mm-dd_hhmm%.log"  "cyan"  
else
  write-utclog "log file : ${logfile}"  "cyan"  
fi
write-utclog "aikey : ${ikey}"  "cyan"
write-utclog "containerid : ${cid}"  "cyan"
write-utclog "ping interval : ${interval}"  "cyan"

# main function of ping
#ping -O $ipaddr -W 1 -i $interval | while read pong; do echo "$(date -u +'%F %H:%M:%S.%3N'),${cid},$(hostname -s),${tid},${pong}"; echo "$(date -u +'%F %H:%M:%S,%3N'),${tid},${pong}" | iconv -t UTF-8 >> $logfile ; send-aievent "${ikey}" "${pong}" "${ipaddr}" "${tid}" "${cid}"; done 2>&1 
ping -O $ipaddr -W 1 -i $interval | while read pong; do echo "$(date -u +'%F %H:%M:%S.%3N'),${cid},$(hostname -s),${tid},${ipaddr},${pong}"; appendtimedlog "$(date -u +'%F %H:%M:%S.%3N'),${cid},$(hostname -s),${tid},${ipaddr},${pong}" "${logfile}" "${timedlog}" ; send-aievent "${ikey}" "${pong}" "${ipaddr}" "${tid}" "${cid}"; done 2>&1 
