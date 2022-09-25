Set ip=10.10.81.160
set ip=192.168.10.1

rem goto :fulltunnel
rem add o365 address & 8075
rem https://docs.microsoft.com/en-us/office365/enterprise/urls-and-ip-address-ranges#skype-for-business-online-and-microsoft-teams
route add 3.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 13.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 20.0.0.0  mask 255.0.0.0 %ip% metric 1	    
route add 23.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 40.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 51.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 52.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 64.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 68.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 70.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 72.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 74.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 94.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 98.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 102.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 104.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 108.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 111.221.0.0 mask 255.255.0.0 %ip% metric 1
route add 128.94.0.0  mask 255.255.0.0 %ip% metric 1	
route add 131.253.0.0 mask 255.255.0.0 %ip% metric 1
route add 132.245.0.0 mask 255.255.0.0 %ip% metric 1
route add 134.170.0.0  mask 255.255.0.0 %ip% metric 1	
route add 135.149.0.0  mask 255.255.0.0 %ip% metric 1	
route add 137.116.0.0  mask 255.255.0.0 %ip% metric 1	
route add 137.117.0.0  mask 255.255.0.0 %ip% metric 1	
route add 137.135.0.0  mask 255.255.0.0 %ip% metric 1	
route add 138.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 143.64.0.0  mask 255.255.0.0 %ip% metric 1	
route add 147.145.0.0  mask 255.255.0.0 %ip% metric 1	
route add 147.243.0.0  mask 255.255.0.0 %ip% metric 1	
route add 148.7.0.0  mask 255.255.0.0 %ip% metric 1	
route add 150.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 155.62.0.0  mask 255.255.0.0 %ip% metric 1	
route add 157.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 158.158.0.0  mask 255.255.0.0 %ip% metric 1	
route add 159.27.0.0  mask 255.255.0.0 %ip% metric 1	
route add 163.228.0.0  mask 255.255.0.0 %ip% metric 1	
route add 167.105.0.0  mask 255.255.0.0 %ip% metric 1	
route add 168.61.0.0  mask 255.255.0.0 %ip% metric 1	
route add 168.62.0.0  mask 255.254.0.0 %ip% metric 1	
route add 169.138.0.0  mask 255.255.0.0 %ip% metric 1	
route add 170.165.0.0  mask 255.255.0.0 %ip% metric 1	
route add 191.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 204.0.0.0 mask 255.0.0.0 %ip% metric 1

rem add 8075 https://bgp.he.net/AS8075#_prefixes
route add 192.48.225.0  mask 255.255.255.0 %ip% metric 1	
route add 192.84.160.0  mask 255.255.255.0 %ip% metric 1	
route add 192.84.161.0  mask 255.255.255.0 %ip% metric 1	
route add 192.100.104.0  mask 255.255.248.0 %ip% metric 1
route add 192.100.112.0  mask 255.255.248.0 %ip% metric 1
route add 192.100.120.0  mask 255.255.248.0 %ip% metric 1
route add 192.100.128.0  mask 255.255.252.0 %ip% metric 1
route add 192.197.157.0  mask 255.255.255.0 %ip% metric 1
route add 193.149.64.0  mask 255.255.224.0 %ip% metric 1	
route add 193.221.113.0  mask 255.255.255.0 %ip% metric 1
route add 194.41.16.0  mask 255.255.240.0 %ip% metric 1	
route add 198.49.8.0  mask 255.255.255.0 %ip% metric 1	
route add 198.180.97.0  mask 255.255.255.0 %ip% metric 1	
route add 198.200.130.0  mask 255.255.255.0 %ip% metric 1
route add 198.206.164.0  mask 255.255.255.0 %ip% metric 1
route add 199.30.16.0  mask 255.255.240.0 %ip% metric 1	
route add 199.60.28.0  mask 255.255.255.0 %ip% metric 1	
route add 199.103.90.0  mask 255.255.254.0 %ip% metric 1	
route add 199.103.122.0  mask 255.255.255.0 %ip% metric 1
route add 199.242.32.0  mask 255.255.240.0 %ip% metric 1	
route add 199.242.48.0  mask 255.255.248.0 %ip% metric 1	
route add 202.89.224.0  mask 255.255.248.0 %ip% metric 1	
route add 204.79.135.0  mask 255.255.255.0 %ip% metric 1	
route add 204.79.179.0  mask 255.255.255.0 %ip% metric 1	
route add 204.79.195.0  mask 255.255.255.0 %ip% metric 1	
route add 204.79.252.0  mask 255.255.255.0 %ip% metric 1	
route add 204.95.96.0  mask 255.255.240.0 %ip% metric 1	
route add 204.152.140.0  mask 255.255.254.0 %ip% metric 1
route add 206.138.168.0  mask 255.255.248.0 %ip% metric 1
route add 206.191.224.0  mask 255.255.224.0 %ip% metric 1
route add 207.46.0.0  mask 255.255.224.0 %ip% metric 1	
route add 207.46.36.0  mask 255.255.252.0 %ip% metric 1	
route add 207.46.40.0  mask 255.255.248.0 %ip% metric 1	
route add 207.46.48.0  mask 255.255.240.0 %ip% metric 1	
route add 207.46.64.0  mask 255.255.192.0 %ip% metric 1	
route add 207.46.128.0  mask 255.255.128.0 %ip% metric 1	
route add 207.68.128.0  mask 255.255.192.0 %ip% metric 1	
route add 208.68.136.0  mask 255.255.248.0 %ip% metric 1	
route add 208.76.45.0  mask 255.255.255.0 %ip% metric 1	
route add 208.76.46.0  mask 255.255.255.0 %ip% metric 1	
route add 208.84.0.0  mask 255.255.0.0 %ip% metric 1	
route add 209.240.192.0  mask 255.255.224.0 %ip% metric 1
route add 213.199.128.0  mask 255.255.192.0 %ip% metric 1
route add 216.32.180.0  mask 255.255.252.0 %ip% metric 1	
route add 216.220.208.0  mask 255.255.240.0 %ip% metric 1

rem https://bgp.he.net/AS32934#_prefixes  (facebook)
route add 31.13.24.0 mask 255.255.248.0 %ip% metric 1
route add 31.13.0.0 mask 255.255.0.0 %ip% metric 1	
route add 45.64.40.0 mask 255.255.252.0 %ip% metric 1	
route add 66.220.0.0 mask 255.255.0.0 %ip% metric 1	
route add 66.220.152.0 mask 255.255.248.0 %ip% metric 1	
route add 69.63.176.0 mask 255.255.240.0 %ip% metric 1	
route add 69.171.0.0 mask 255.255.0.0 %ip% metric 1	
route add 74.119.76.0 mask 255.255.252.0 %ip% metric 1	
route add 102.132.0.0 mask 255.255.0.0 %ip% metric 1	
route add 103.4.96.0 mask 255.255.252.0 %ip% metric 1	
route add 129.134.0.0 mask 255.255.0.0 %ip% metric 1	
route add 157.240.0.0 mask 255.255.0.0 %ip% metric 1	
route add 173.252.64.0 mask 255.255.224.0 %ip% metric 1	
route add 173.252.88.0 mask 255.255.248.0 %ip% metric 1	
route add 173.252.96.0 mask 255.255.224.0 %ip% metric 1	
route add 179.60.192.0 mask 255.255.248.0 %ip% metric 1	
route add 185.89.218.0 mask 255.255.252.0 %ip% metric 1	
route add 204.15.20.0 mask 255.255.252.0 %ip% metric 1	

rem route add 0.0.0.0 mask 0.0.0.0 100.64.44.32 metric 
rem add google ip range https://www.lifewire.com/what-is-the-ip-address-of-google-818153
route add 64.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 66.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 72.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 74.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 209.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 216.0.0.0 mask 255.0.0.0 %ip% metric 1

rem corp
route add 10.0.0.0 mask 255.0.0.0 %ip% metric 1
route add 172.0.0.0 mask 255.0.0.0 %ip% metric 1

rem wireshark  AS14061
route add 198.199.88.0 mask 255.255.252.0 %ip% metric 1

rem add case buddy
route add 168.63.0.0 mask 255.255.0.0 %ip% metric 1

:fulltunnel
rem route add 192.168.3.0 mask 255.255.255.0 %ip% metric 1


rem replace
rem / 32 mask 255.255.255.255 %ip% metric 1
rem / 31 mask 255.255.255.254 %ip% metric 1
rem / 30 mask 255.255.255.252 %ip% metric 1
rem / 29 mask 255.255.255.248 %ip% metric 1
rem / 28 mask 255.255.255.240 %ip% metric 1
rem / 27 mask 255.255.255.224 %ip% metric 1
rem / 26 mask 255.255.255.192 %ip% metric 1
rem / 25 mask 255.255.255.128 %ip% metric 1
rem / 24 mask 255.255.255.0 %ip% metric 1
rem / 23 mask 255.255.254.0 %ip% metric 1
rem / 22 mask 255.255.252.0 %ip% metric 1
rem / 21 mask 255.255.248.0 %ip% metric 1
rem / 20 mask 255.255.240.0 %ip% metric 1
rem / 19 mask 255.255.224.0 %ip% metric 1
rem / 18 mask 255.255.192.0 %ip% metric 1
rem / 17 mask 255.255.128.0 %ip% metric 1
rem / 16 mask 255.255.0.0 %ip% metric 1
rem / 15 mask 255.254.0.0 %ip% metric 1
rem / 14 mask 255.252.0.0 %ip% metric 1
rem / 13 mask 255.248.0.0 %ip% metric 1
rem / 12 mask 255.240.0.0 %ip% metric 1
rem / 11 mask 255.224.0.0 %ip% metric 1
rem / 10 mask 255.192.0.0 %ip% metric 1
rem / 9  mask 255.128.0.0 %ip% metric 1
rem / 8  mask 255.0.0.0 %ip% metric 1
rem / 7  mask 254.0.0.0 %ip% metric 1
rem / 6  mask 252.0.0.0 %ip% metric 1
rem / 5  mask 248.0.0.0 %ip% metric 1
rem / 4  mask 240.0.0.0 %ip% metric 1
rem / 3  mask 224.0.0.0 %ip% metric 1
rem / 2  mask 192.0.0.0 %ip% metric 1
rem / 1  mask 128.0.0.0 %ip% metric 1

