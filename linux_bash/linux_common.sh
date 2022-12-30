# author  qliu@microsoft.com

learningbash="this script config linux with basic software"
echo $learningbash

# installation
sudo apt update -y
sudo apt upgrade -y
sudo apt install netfilter-persistent net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute -y

