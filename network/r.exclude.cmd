set ip=192.168.3.1

rem route add 23.98.36.69 mask 255.255.255.255 %ip% metric 1 -p
rem route add 65.52.171.121 mask 255.255.255.255 %ip% metric 1 -p
route add 13.75.112.40 mask 255.255.255.255 %ip% metric 1 -p

rem add ChinaNET AS4134
route add 115.224.0.0 mask 255.240.0.0 %ip% metric 1 -p
route add 114.80.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 62.234.0.0 mask 255.255.0.0 %ip% metric 1 -p

rem add mooncake ip
route add 40.72.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 40.73.0.0 mask 255.255.0.0 %ip% metric 1 -p 
route add 40.125.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 40.126.0.0 mask 255.255.0.0 %ip% metric 1 -p 
route add 42.159.0.0 mask 255.255.0.0 %ip% metric 1 -p 
route add 139.217.0.0 mask 255.255.0.0 %ip% metric 1 -p 
route add 139.219.0.0 mask 255.255.0.0 %ip% metric 1 -p 

rem add ChinaTelecom IP
route add 49.7.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 122.240.0.0 mask 255.248.0.0 %ip% metric 1 -p
route add 183.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 180.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 202.96.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 220.0.0.0 mask 255.0.0.0 %ip% metric 1 -p

rem route add 180.149.0.0 mask 255.255.0.0 %ip% metric 1 -p

rem add China Mobile
route add 27.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 36.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 39.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 61.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
#route add 103.0.0.0 mask 255.0.0.0 %ip% metric 1 -p  this is causing issue when access aadcdn.msftauth.cn
route add 111.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 118.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 120.204.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 211.136.0.0 mask 255.248.0.0 %ip% metric 1 -p
route add 223.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 221.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 218.206.0.0 mask 255.254.0.0 %ip% metric 1 -p

rem add china unicom 
route add 116.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 120.52.128.0 mask 255.255.128.0 %ip% metric 1 -p
route add 123.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 140.207.0.0 mask 255.255.0.0 %ip% metric 1 -p


rem add Aliyun ip 
rem SG 8.209.0.0/19
rem SG 8.208.0.0 mask 255.255.0.0 %ip% metric 1 -p
rem SG 170.33.0.0 mask 255.255.0.0
route add 8.133.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 39.100.0.0 mask 255.240.0.0 %ip% metric 1 -p
route add 39.96.0.0 mask 255.248.0.0 %ip% metric 1 -p
route add 42.120.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 47.100.0.0 mask 255.248.0.0 %ip% metric 1 -p
route add 47.92.0.0 mask 255.248.0.0 %ip% metric 1 -p
route add 59.110.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 59.82.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 60.205.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 101.132.0.0 mask 255.254.0.0 %ip% metric 1 -p
route add 101.200.0.0 mask 255.254.0.0 %ip% metric 1 -p
route add 103.15.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 104.205.0.0 mask 255.254.0.0 %ip% metric 1 -p
route add 106.11.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 106.14.0.0 mask 255.254.0.0 %ip% metric 1 -p
route add 110.76.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 112.0.0.0 mask 255.0.0.0 %ip% metric 1 -p
route add 114.215.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 114.55.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 115.28.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 115.29.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 116.62.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 118.178.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 118.190.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 118.31.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 119.23.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 120.24.0.0 mask 255.252.0.0 %ip% metric 1 -p
route add 120.55.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 120.76.0.0 mask 255.240.0.0 %ip% metric 1 -p
route add 120.199.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 120.199.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 120.221.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 121.89.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 121.196.0.0 mask 255.248.0.0 %ip% metric 1 -p
route add 121.40.0.0 mask 255.240.0.0 %ip% metric 1 -p
route add 123.56.0.0 mask 255.254.0.0 %ip% metric 1 -p
route add 139.129.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 139.196.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 139.224.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 182.92.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 203.107.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 203.119.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 203.209.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 218.224.0.0 mask 255.255.224.0 %ip% metric 1 -p
route add 218.244.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 223.4.0.0 mask 255.240.0.0 %ip% metric 1 -p



rem add Tencent IP
route add 101.32.0.0 mask 255.240.0.0 %ip% metric 1 -p
route add 115.159.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 118.193.96.0 mask 255.255.224.0 %ip% metric 1 -p
route add 119.28.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 119.29.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 121.51.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 150.109.23.0 mask 255.255.255.0 %ip% metric 1 -p
route add 182.254.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 203.205.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 203.205.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 211.152.148.0 mask 255.255.255.0 %ip% metric 1 -p 

rem add iQiyi, ASN  AS133865 
route add 39.156.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 36.110.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 43.225.84.0 mask 255.255.252.0 %ip% metric 1 -p
route add 103.44.56.0 mask 255.255.252.0 %ip% metric 1 -p
route add 118.26.0.0 mask 255.255.0.0 %ip% metric 1 -p
rem route add 118.26.34.0 mask 255.255.252.0 %ip% metric 1 -p
rem route add 118.26.96.0 mask 255.255.240.0 %ip% metric 1 -p
route add 103.98.125.0 mask 255.255.255.0 %ip% metric 1 -p
route add 103.98.127.0 mask 255.255.255.0 %ip% metric 1 -p
route add 103.98.248.0 mask 255.255.240.0.0 %ip% metric 1 -p
route add 129.227.142.0 mask 255.255.255.0 %ip% metric 1 -p

rem NetEase
route add 43.240.84.0    mask 255.255.252.0 %ip% metric 1 -p	
route add 43.247.76.0    mask 255.255.252.0 %ip% metric 1 -p	
route add 43.247.96.0    mask 255.255.252.0 %ip% metric 1 -p	
route add 43.255.48.0    mask 255.255.252.0 %ip% metric 1 -p	
route add 103.4.224.0    mask 255.255.252.0 %ip% metric 1 -p	
route add 103.36.72.0    mask 255.255.252.0 %ip% metric 1 -p	
route add 103.205.52.0   mask 255.255.252.0 %ip% metric 1 -p	
route add 103.233.104.0  mask 255.255.252.0 %ip% metric 1 -p
route add 103.237.68.0   mask 255.255.252.0 %ip% metric 1 -p	
route add 103.248.124.0  mask 255.255.252.0 %ip% metric 1 -p
route add 114.113.216.0  mask 255.255.252.0 %ip% metric 1 -p
route add 202.14.172.0   mask 255.255.252.0 %ip% metric 1 -p	
route add 203.95.208.0   mask 255.255.252.0 %ip% metric 1 -p	
route add 122.198.64.0   mask 255.255.252.0 %ip% metric 1 -p	
route add 114.113.216.0  mask 255.255.254.0 %ip% metric 1 -p
route add 114.113.218.0  mask 255.255.254.0 %ip% metric 1 -p
route add 122.198.64.0   mask 255.255.254.0 %ip% metric 1 -p	
route add 223.252.224.0  mask 255.255.224.0 %ip% metric 1 -p

rem Akamai
route add 36.110.0.0 mask 255.255.0.0 %ip% metric 1 -p
route add 23.48.0.0 mask 255.255.0.0 %ip% metric 1 -p

rem replace
rem / 32 mask 255.255.255.255 %ip% metric 1 -p
rem / 31 mask 255.255.255.254 %ip% metric 1 -p
rem / 30 mask 255.255.255.252 %ip% metric 1 -p
rem / 29 mask 255.255.255.248 %ip% metric 1 -p
rem / 28 mask 255.255.255.240 %ip% metric 1 -p
rem / 27 mask 255.255.255.224 %ip% metric 1 -p
rem / 26 mask 255.255.255.192 %ip% metric 1 -p
rem / 25 mask 255.255.255.128 %ip% metric 1 -p
rem / 24 mask 255.255.255.0 %ip% metric 1 -p
rem / 23 mask 255.255.254.0 %ip% metric 1 -p
rem / 22 mask 255.255.252.0 %ip% metric 1 -p
rem / 21 mask 255.255.248.0 %ip% metric 1 -p
rem / 20 mask 255.255.240.0 %ip% metric 1 -p
rem / 19 mask 255.255.224.0 %ip% metric 1 -p
rem / 18 mask 255.255.192.0 %ip% metric 1 -p
rem / 17 mask 255.255.128.0 %ip% metric 1 -p
rem / 16 mask 255.255.0.0 %ip% metric 1 -p
rem / 15 mask 255.254.0.0 %ip% metric 1 -p
rem / 14 mask 255.252.0.0 %ip% metric 1 -p
rem / 13 mask 255.248.0.0 %ip% metric 1 -p
rem / 12 mask 255.240.0.0 %ip% metric 1 -p
rem / 11 mask 255.224.0.0 %ip% metric 1 -p
rem / 10 mask 255.192.0.0 %ip% metric 1 -p
rem / 9  mask 255.128.0.0 %ip% metric 1 -p
rem / 8  mask 255.0.0.0 %ip% metric 1 -p
rem / 7  mask 254.0.0.0 %ip% metric 1 -p
rem / 6  mask 252.0.0.0 %ip% metric 1 -p
rem / 5  mask 248.0.0.0 %ip% metric 1 -p
rem / 4  mask 240.0.0.0 %ip% metric 1 -p
rem / 3  mask 224.0.0.0 %ip% metric 1 -p
rem / 2  mask 192.0.0.0 %ip% metric 1 -p
rem / 1  mask 128.0.0.0 %ip% metric 1 -p
