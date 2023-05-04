#!/bin/bash

#author: qliu

learningbash="This script config linux with basic software"
echo $learningbash

# installation
sudo apt update -y
sudo apt upgrade -y
sudo apt install netfilter-persistent net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute iotop iftop iperf3 netcat apache2-utils moreutils tshark -y

# add powershell 
sudo snap install powershell --classic  # LEGACY, but working in Ubuntu 22

# sudo apt install dotnet-sdk-5.0 -y
# dotnet tool install --global PowerShell 

# install a web server
sudo apt install apache2 -y
sudo systemctl start apache2
sudo systemctl enable apache2

# create a default webpage for apache2 and include the hostname
sudo echo "<html><body><h1>$(hostname)</h1></body></html>" > /var/www/html/index.html


