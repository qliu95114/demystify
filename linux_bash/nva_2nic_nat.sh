#!/bin/bash
# author  qliu

learningbash="this script config NVA with two nics, NAT"
echo $learningbash

# installation
sudo apt update -y
sudo apt upgrade -y
sudo apt install netfilter-persistent net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute iotop iftop -y

# allow probe work on eth1
#sudo arp -i eth1 -s 168.63.129.16 12:34:56:78:9a:bc  
#ETH1_IP=$(ip addr show dev eth1 | grep 'inet '|awk '{print $2}'|awk -F '/' '{print $1}')
#sudo ip route add 168.63.129.16/32 via $ETH1_IP

# config NAT on eth0 public, eth1 internal
#sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#sudo iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
#sudo iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
#sudo sysctl -w net.ipv4.ip_forward=1
#sudo netfilter-persistent save
#sudo netfilter-persistent reload

# add persistent when linux reboot or interface up
sudo echo "sudo arp -i eth1 -s 168.63.129.16 12:34:56:78:9a:bc" > /etc/init.d/allow-probe
sudo echo "sudo ip route add 168.63.129.16/32 via $(ip addr show dev eth1 | grep 'inet '|awk '{print $2}'|awk -F '/' '{print $1}')" >> /etc/init.d/allow-probe
sudo echo "sudo sysctl -w net.ipv4.ip_forward=1" >> /etc/init.d/allow-probe
sudo echo "sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE" >> /etc/init.d/allow-probe
sudo echo "sudo iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT" >> /etc/init.d/allow-probe
sudo echo "sudo iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT" >> /etc/init.d/allow-probe
sudo chmod +x /etc/init.d/allow-probe
echo "===cat /etc/init.d/allow-probe===="
sudo cat /etc/init.d/allow-probe
echo "===end of /etc/init.d/allow-probe===="
sudo bash /etc/init.d/allow-probe

#make it auto run on every start
sudo crontab -l | { cat; echo "@reboot /etc/init.d/allow-probe"; } | crontab -
#sudo crontab - <<< "@reboot /etc/init.d/allow-probe"

#sudo echo "@reboot /etc/init.d/allow-probe" > /var/spool/cron/crontabs/root  # this won't work, the file should not be modified directly 
#sudo echo "" >> /var/spool/cron/crontabs/root

#sudo echo "/etc/init.d/allow-probe" > /etc/rc.local
#sudo echo "exit 0" >> /etc/rc.local
#sudo chmod +x /etc/rc.local