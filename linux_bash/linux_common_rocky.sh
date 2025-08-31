#!/bin/bash

#author: qliu

learningbash="This script config linux(redhat/rocky/centos) with basic software"
echo $learningbash

# installation, when install tshark it will prompt diaglog for dumpcap setting, 
sudo dnf update -y
sudo dnf upgrade -y
sudo dnf install epel-release -y
#sudo yum install net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute iotop iftop iperf3 moreutils ufw nginx samba -y
sudo dnf install net-tools iptables tcpdump nano vim iotop iperf3 iftop nginx samba firewalld -y


# sudo apt install dotnet
sudo dnf update -y 
sudo rpm -Uvh https://packages.microsoft.com/config/centos/8/packages-microsoft-prod.rpm
#sudo dnf install dotnet-sdk-8.0 -y 
#sudo dnf install dotnet-runtime-8.0 -y
sudo dnf install dotnet-sdk-9.0 aspnetcore-runtime-9.0 -y

# add powershell 
sudo dnf install https://github.com/PowerShell/PowerShell/releases/download/v7.5.1/powershell-7.5.1-1.rh.x86_64.rpm -y

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
sudo systemctl start firewalld
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent

# Enable the firewall to allow Samba traffic
sudo firewall-cmd --zone=public --add-port=445/tcp --permanent
sudo firewall-cmd --zone=public --add-port=2222/tcp --permanent
sudo firewall-cmd --zone=public --add-port=22/tcp --permanent

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


## Change the SSH port to 220
## Define the new SSH port
#NEW_PORT=2222
#
## Path to the SSH configuration file 
#SSH_CONFIG_FILE="/etc/ssh/sshd_config"
#
## Backup the current SSH configuration file
#sudo cp $SSH_CONFIG_FILE "${SSH_CONFIG_FILE}.bak"
#
## Update the SSH configuration file with the new port
#sudo sed -i "/Port 22/d" $SSH_CONFIG_FILE  # remove the comment
#echo "Port $NEW_PORT" | sudo tee -a $SSH_CONFIG_FILE # add the new port
#
## Restart the SSH service to apply changes
#sudo systemctl restart sshd
#
## Verify the change
#if sudo ss -tuln | grep ":$NEW_PORT"; then
#  echo "SSH port successfully changed to $NEW_PORT."
#else
#  echo "Failed to change SSH port."
#fi
