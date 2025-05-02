#!/bin/bash

#author: qliu

learningbash="This script config linux with basic software"
echo $learningbash

# installation, when install tshark it will prompt diaglog for dumpcap setting, 
sudo apt update -y
sudo apt upgrade -y
sudo apt install netfilter-persistent net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute iotop iftop iperf3 netcat moreutils ufw nginx samba -y

# add powershell 
sudo snap install powershell --classic  # LEGACY, but working in Ubuntu 22

# sudo apt install dotnet-sdk-5.0 -y
# dotnet tool install --global PowerShell 

# MaxKeepAliveRequests: The maximum number of requests to allow
# during a persistent connection. Set to 0 to allow an unlimited amount.
# sudo sed -i 's/MaxKeepAliveRequests 100/MaxKeepAliveRequests 999/g' /etc/apache2/apache2.conf
# sudo sed -i 's/KeepAliveTimeout 5/KeepAliveTimeout 30/g' /etc/apache2/apache2.conf

# please update keepavlie_requests if it does not exist, otherwise update the value
if [ ! -f /etc/nginx/nginx.conf ]; then
  echo "nginx.conf does not exist"
else
  echo "nginx.conf exists, updating keepalive_requests..."
  if grep -q "keepalive_requests" /etc/nginx/nginx.conf; then
    sudo sed -i 's/keepalive_requests [0-9]\+/keepalive_requests 1000000/' /etc/nginx/nginx.conf
  else
    sudo sed -i '/http {/a \    keepalive_requests 1000000;' /etc/nginx/nginx.conf
  fi
  if grep -q "keepalive_timeout" /etc/nginx/nginx.conf; then
    sudo sed -i 's/keepalive_timeout [0-9]\+/keepalive_timeout 180 180/' /etc/nginx/nginx.conf
  else
    sudo sed -i '/http {/a \    keepalive_timeout 180 180;' /etc/nginx/nginx.conf
  fi  
fi

# create a default webpage to show hostname in nginx
sudo echo "<html><body><h1>$(hostname)</h1></body></html>" | sudo tee /var/www/html/hostname.html

# Generate a random size html with size between 0 and 1024
RANDOM_SIZE=$(( ( RANDOM % 1024 )  + 1 ))

# Fill the file with random number of "A" characters
sudo echo "<html><body><h1>" | sudo tee /var/www/html/random.html
for i in $(seq 1 $RANDOM_SIZE); do
    sudo echo -n "A" | sudo tee -a /var/www/html/random.html
done
sudo echo "</h1></body></html>" | sudo tee -a /var/www/html/random.html

# open tcpport 80 to allow web traffic
sudo ufw allow 80/tcp

# install a web server
sudo systemctl start nginx
sudo systemctl enable nginx

# supress wireshark installation
#echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
#sudo DEBIAN_FRONTEND=noninteractive apt-get -y install wireshark tshark

# Create a backup of the original Samba configuration file
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# Configure Samba by editing the smb.conf file
mkdir /tmp/logfolder
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[logfolder]
  comment = this is folder for logging
  path = /tmp/logfolder
  browseable = yes
  guest ok = yes
  read only = no
  create mask = 0777
  directory mask = 0777
EOF

# Restart the Samba service
sudo systemctl restart smbd

# Enable the firewall to allow Samba traffic
sudo ufw allow samba
sudo ufw reload

# Change the SSH port to 220
# Define the new SSH port
NEW_PORT=2222

# Path to the SSH configuration file 
SSH_CONFIG_FILE="/etc/ssh/sshd_config"

# Backup the current SSH configuration file
sudo cp $SSH_CONFIG_FILE "${SSH_CONFIG_FILE}.bak"

# Update the SSH configuration file with the new port
sudo sed -i "s/^#Port 22/Port $NEW_PORT/" $SSH_CONFIG_FILE
sudo sed -i "s/^Port 22/Port $NEW_PORT/" $SSH_CONFIG_FILE

# Restart the SSH service to apply changes
sudo systemctl restart sshd

# Verify the change
if sudo ss -tuln | grep ":$NEW_PORT"; then
  echo "SSH port successfully changed to $NEW_PORT."
else
  echo "Failed to change SSH port."
fi
