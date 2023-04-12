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

