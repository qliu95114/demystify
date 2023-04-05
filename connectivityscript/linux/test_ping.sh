#!/bin/bash

# This script will run ping test
# options: 
# dns or ipaddress
# logfile include path and file name

# Examples:
# Ping 8.8.4.4 and output log to /tmp/myping.log
# test_ping.sh 8.8.4.4 /tmp/myping.log


send-aievent() {
  ikey=$1
  PreciseTime=$2
  # Replace with your custom event name
  event_name="test_ping.sh"

  # Replace with your event data
  event_data='{"PreciseTime": "PreciseTime", "property2": 123, "property3": true}'

  # Set the URL for the Application Insights endpoint
  url="https://dc.services.visualstudio.com/v2/track"

  # Create the JSON payload
  json_payload="{ \"name\": \"$event_name\", \"data\": $event_data }"

  # Send the payload using cURL in the background
  # curl -sS -X POST -H "Content-Type: application/x-json-stream" -d "$json_payload" "$url" > /dev/null 2>&1 &
  curl -sS -X POST -H "Content-Type: application/x-json-stream" -d "$json_payload" "$url" 

  echo "Event sent asynchronously"
}

write-utclog() {
  # Get current UTC time
  utc_time=$(date -u +"%Y-%m-%d %H:%M:%S")
  
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

if [ -z "$1" ] 
then
  read -p "Enter your target ip address or dns name (e.g. 8.8.8.8 or dns.google):" ipaddr
else
  ipaddr=$1
fi

if [ -z "$2" ]
then
  logfile="/tmp/$(hostname -s)_longping_${ipaddr}.log"
else
  logfile=$2
fi

if [ -z "$3" ]
then
  ikey="abc"
else
  ikey=$3  # Replace with your instrumentation key
  utc_time=$(date -u +"%Y-%m-%d %H:%M:%S")
  send-aievent $ikey $utc_time
fi

write-utclog "target dns or ip : ${ipaddr}" "cyan"
write-utclog "${logfile}"  "cyan"

ping -O $ipaddr -i 1 | while read pong; do echo "$(date -u +'%F %H:%M:%S'),$pong"; done 2>&1 | tee $logfile
