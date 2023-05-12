retry_delay=10

configjson="https://pingmeshdigitalnative.blob.core.windows.net/config/config.json"

while true; do
    response=$(curl -sS $configjson)
    status=$(echo $response | grep -o '"status":[^,}]*' | awk -F':' '{print $2}' | sed 's/[^0-9]*//g')
    if [ $status -ne 200 ]; then
        echo "Received non-200 status code $status"
        continue
    fi
    config=$(echo $response | grep -o '"content":[^,}]*' | awk -F':' '{print $2}' | sed 's/^"//' | sed 's/"$//')
    echo "Download $configjson successfully"
    break  # exit loop if successful
done

containerid=$(curl -s -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A "" "http://168.63.129.16/machine?comp=goalstate" | grep -oPm1 "(?<=<ContainerId>)[^<]+")

if [ -z "$containerid" ]; then
    containerid="00000000-0000-0000-0000-000000000000"
fi

echo "containerid is $containerid"

env=$(echo $config | grep -o '"env":[^,}]*' | awk -F':' '{print $2}' | sed 's/^"//' | sed 's/"$//')
timeout=$(echo $config | grep -o '"timeout":[^,}]*' | awk -F':' '{print $2}' | sed 's/[^0-9]*//g')
delay=$(echo $config | grep -o '"delay":[^,}]*' | awk -F':' '{print $2}' | sed 's/[^0-9]*//g')

for ip in $(grep -oP 'iplist":\[\K[^\]]+' config.json | tr -d '",' | tr ' ' '\n'); do
    ipaddr=$(ip -f inet addr show eth0 | grep -Po 'inet \K[\d.]+')
    if [ "$ipaddr" = "$ip" ]; then
        echo "Skip $ipaddr"
        continue
    else
        # do something
        echo "Processing $ip"
    fi
    sleep 2 # add 2 seconds delay for each ip to slow down the process
done