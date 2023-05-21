retry=0

# Loop until file download is successful or retry limit is reached
mkdir /home/pingmesh
while [ $retry -lt 10 ]; do
  # Download the config.ini file
  sudo wget "https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/linux/pingmesh/pingmesh_core.sh" -O /etc/init.d/pingmesh_core
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
  echo "Failed to download pingmesh_core after 10 retries" >> /home/pingmesh/pingmesh_bootstrap.log
  exit 1
fi

# sample add cron job and lanuch /etc/init.d/pingmesh_core on every reboot
sudo crontab -l | { cat; echo "@reboot /etc/init.d/pingmesh_core"; } | crontab -

bash /etc/init.d/pingmesh_core





