#!/bin/bash
# author  qliu  

learningbash="this script config NVA with two nics, GatewayLoadBalancer"
echo $learningbash

# installation
sudo apt update -y
sudo apt upgrade -y
sudo apt install netfilter-persistent net-tools iptables tcpdump nano vim iputils-ping cron inetutils-traceroute iotop iftop -y

sudo echo "sudo arp -i eth1 -s 168.63.129.16 12:34:56:78:9a:bc" > /etc/init.d/allow-probe
sudo echo "sudo ip route add 168.63.129.16/32 via $(ip addr show dev eth1 | grep 'inet '|awk '{print $2}'|awk -F '/' '{print $1}')" >> /etc/init.d/allow-probe
sudo echo "sudo ip link add outvxlan type vxlan id 800 remote 192.168.12.132 dstport 10800 dev eth1" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set outvxlan up" >> /etc/init.d/allow-probe

sudo echo "sudo ip link add invxlan type vxlan id 801 remote 192.168.12.132 dstport 10801 dev eth1" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set invxlan up" >> /etc/init.d/allow-probe

sudo echo "sudo sysctl -w net.ipv6.conf.invxlan.accept_ra=0" >> /etc/init.d/allow-probe
sudo echo "sudo sysctl -w net.ipv6.conf.invxlan.autoconf=0" >> /etc/init.d/allow-probe
sudo echo "sudo sysctl -w net.ipv6.conf.outvxlan.accept_ra=0" >> /etc/init.d/allow-probe
sudo echo "sudo sysctl -w net.ipv6.conf.outvxlan.autoconf=0" >> /etc/init.d/allow-probe

sudo echo "sudo sysctl -w net.ipv4.ip_forward=1" >> /etc/init.d/allow-probe

sudo echo "sudo ip link add name br0 type bridge" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set dev invxlan master br0" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set dev outvxlan master br0" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set eth1 mtu 4000" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set invxlan mtu 3900" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set outvxlan mtu 3900" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set br0 mtu 3900" >> /etc/init.d/allow-probe
sudo echo "sudo ip link set dev br0 up" >> /etc/init.d/allow-probe

sudo chmod +x /etc/init.d/allow-probe
echo "===cat /etc/init.d/allow-probe===="
sudo cat /etc/init.d/allow-probe
echo "===end of /etc/init.d/allow-probe===="
sudo bash /etc/init.d/allow-probe

#make it auto run on every start
sudo crontab -l | { cat; echo "@reboot /etc/init.d/allow-probe"; } | crontab -