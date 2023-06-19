sa="pingmeshlogwestus3"
sakey="****************************************************************************************"

retry=0

# Loop until file download is successful or retry limit is reached
mkdir /home/pingmesh
while [ $retry -lt 10 ]; do
  # Download the config.ini file
  sudo wget "https://raw.githubusercontent.com/qliu95114/demystify/main/connectivityscript/linux//pingmesh_core.sh" -O /etc/init.d/pingmesh_core
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

chmod +x /etc/init.d/pingmesh_core

# sample add cron job and lanuch /etc/init.d/pingmesh_core on every reboot
sudo crontab -l | { cat; echo "@reboot /etc/init.d/pingmesh_core"; } | crontab -

# mount storage 
sudo mkdir /mnt/shein
if [ ! -d "/etc/smbcredentials" ]; then
sudo mkdir /etc/smbcredentials
fi
if [ ! -f "/etc/smbcredentials/${sa}.cred" ]; then
    sudo bash -c 'echo "username=${sa}" >> /etc/smbcredentials/${sa}.cred'
    sudo bash -c 'echo "password=${sakey}" >> /etc/smbcredentials/${sakey}.cred'
fi
sudo chmod 600 /etc/smbcredentials/${sa}.cred

sudo bash -c 'echo "//${sa}.file.core.windows.net/shein /mnt/shein cifs nofail,credentials=/etc/smbcredentials/${sa}.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30" >> /etc/fstab'
sudo mount -t cifs //${sa}.file.core.windows.net/shein /mnt/shein -o credentials=/etc/smbcredentials/${sa}.cred,dir_mode=0777,file_mode=0777,serverino,nosharesock,actimeo=30

bash /etc/init.d/pingmesh_core





