retry_delay=10

configjson="https://pingmeshdigitalnative.blob.core.windows.net/config/config.json"

while true; do
    response=$(curl -sS "$configjson")
    if [[ "$?" -ne 0 ]]; then
        echo "Failed to download $configjson. Retrying in $retry_delay seconds..."
        sleep $retry_delay
        continue
    fi

    if [[ "$(echo "$response" | jq -r '.statusCode')" -ne 200 ]]; then
        echo "Received non-200 status code $(echo "$response" | jq -r '.statusCode')"
        echo "Retrying in $retry_delay seconds..."
        sleep $retry_delay
        continue
    fi

    config=$(echo "$response" | jq -r '.content')
    echo "Download $configjson successfully"
    break
done

containerid=$(curl -s -H "x-ms-guest-agent-name: WaAgent-2.7.0.0 (2.7.0.0)" -H "x-ms-version: 2012-11-30" -A "" "http://168.63.129.16/machine?comp=goalstate" | grep -oPm1 "(?<=<ContainerId>)[^<]+")

if [ -z "$containerid" ]; then
    containerid="00000000-0000-0000-0000-000000000000"
fi

echo "containerid is $containerid"

env=$(echo $config | jq -r '.env')
timeout=$(echo $config | jq -r '.timeout')
delay=$(echo $config | jq -r '.delay')

for ip in $(echo $config | jq -r '.iplist[].ip'); do
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