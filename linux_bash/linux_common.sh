#!/bin/bash

#author: qliu

learningbash="This script config linux with basic software"
echo $learningbash

# installation, when install tshark it will prompt diaglog for dumpcap setting, 
sudo apt update -y
sudo apt upgrade -y
sudo apt install netfilter-persistent net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute iotop iftop iperf3 netcat moreutils ufw nginx -y

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
    sudo sed -i 's/keepalive_timeout [0-9]\+/keepalive_requests 1000000/' /etc/nginx/nginx.conf
  else
    sudo sed -i '/http {/a \    keepalive_requests 1000000;' /etc/nginx/nginx.conf
  fi  
fi

# create a default webpage to show hostname in nginx
#sudo echo "<html><body><h1>$(hostname)</h1></body></html>" | sudo tee /var/www/html/hostname.html

# open tcpport 80 to allow web traffic
sudo ufw allow 80/tcp

# install a web server
sudo systemctl start nginx
sudo systemctl enable nginx

# supress wireshark installation
#echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
#sudo DEBIAN_FRONTEND=noninteractive apt-get -y install wireshark tshark