retry=0

# Loop until file download is successful or retry limit is reached
while [ $retry -lt 10 ]; do
  # Download the config.ini file
  wget "https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/linux/config.ini" -O /tmp/config.ini
   # Check if download was successful
  if [ $? -eq 0 ]; then
    break
  fi

  # Increment retry counter
  retry=$((retry+1))

  # Wait for 5 seconds before retrying
  sleep 5
done

if [ $retry -eq 10 ]; then
  echo "Failed to download config.ini after 10 retries"
  exit 1
fi

while [ $retry -lt 10 ]; do
  # Download the test_ping.sh file
   wget "https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/linux/test_ping.sh" -O /tmp/test_ping.sh

   # Check if download was successful
  if [ $? -eq 0 ]; then
    break
  fi
  # Increment retry counter
  retry=$((retry+1))
  # Wait for 5 seconds before retrying
  sleep 5
done

if [ $retry -eq 10 ]; then
  echo "Failed to download test_ping.sh after 10 retries"
  exit 1
fi

# azure get containerid from a vm
curl -s --connect-timeout 0.2 http://168.63.129.16/machine?comp=goalstate -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -o /tmp/cid.xml
containerid=$(sed -n 's:.*<ContainerId>\([^<]*\)</ContainerId>.*:\1:p' /tmp/cid.xml)

if [ -z "$containerid" ]; then
    containerid="00000000-0000-0000-0000-000000000000"
fi
echo "containerid is $containerid"

#read config.ini to settings   
# config.ini format
#[iplist]
#ip = 10.79.11.5,10.79.11.6,10.79.11.7

#read all ip addresses from config.ini
iplist=($(awk -F "=" '/ip/ {print $2}' /tmp/config.ini | sed 's/,/ /g'))

#read interval from config.ini and remove the last character
interval=$(awk -F "=" '/interval/ {print $2}' /tmp/config.ini | sed 's/.$//')

#read timedlog from config.ini and remove the last character
timedlog=$(awk -F "=" '/timedlog/ {print $2}' /tmp/config.ini | sed 's/.$//')


echo "iplist is ${iplist[@]}"
echo "interval is $interval"
echo "timedlog is $timedlog"

#ping all ip addresses

# get my ip address
myip=$(ip addr show dev eth0 | grep 'inet '|awk '{print $2}'|awk -F '/' '{print $1}')

echo "my ip address is $myip"

for ip in "${iplist[@]}"; do
# if my ip address is in the list, skip it
if [ "$ip" == "$myip" ]; then
  echo "my ip address $myip is in the list, skip it"
else
  # ping ip address
  echo "bash /tmp/test_ping.sh $ip ...."
  #nohup ../test_ping.sh $ip 2>&1 &
  bash /tmp/test_ping.sh -ip "$ip" -timedlog $timedlog -interval $interval -logpath "/mnt/$folder" > /dev/null 2>&1 &
fi
done






