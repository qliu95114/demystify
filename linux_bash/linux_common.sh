#!/bin/bash

#author: qliu

learningbash="This script config linux with basic software"
echo $learningbash

# installation, when install tshark it will prompt diaglog for dumpcap setting, 
sudo apt update -y
sudo apt upgrade -y
sudo apt install netfilter-persistent net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute iotop iftop iperf3 netcat apache2-utils moreutils apache2 ufw -y

# add powershell 
sudo snap install powershell --classic  # LEGACY, but working in Ubuntu 22

# sudo apt install dotnet-sdk-5.0 -y
# dotnet tool install --global PowerShell 

# install a web server
sudo systemctl start apache2
sudo systemctl enable apache2

# MaxKeepAliveRequests: The maximum number of requests to allow
# during a persistent connection. Set to 0 to allow an unlimited amount.
sudo sed -i 's/MaxKeepAliveRequests 100/MaxKeepAliveRequests 9999/g' /etc/apache2/apache2.conf
sudo sed -i 's/KeepAliveTimeout 5/KeepAliveTimeout 30/g' /etc/apache2/apache2.conf

# create a default webpage for apache2 and include the hostname
sudo echo "<html><body><h1>$(hostname)</h1></body></html>" | sudo tee /var/www/html/hostname.html

# open tcpport 80 to allow web traffic
sudo ufw allow 80/tcp

# supress wireshark installation
#echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
#sudo DEBIAN_FRONTEND=noninteractive apt-get -y install wireshark tshark