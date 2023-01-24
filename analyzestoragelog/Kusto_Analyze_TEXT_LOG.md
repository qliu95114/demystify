Everyday, I am dealing with different log format but with similar pattern **TIMESTAMP**,**MESSAGE**. Logs are in RAW format. 
I collect a few samples analyze TEXT LOGs with the power of Azure Data Explorer(ADX). To understand the following, I assume you already complete [AnalyzeStorageLog]

# Use ADX to analyze the Linux secure log 

Linux Secure log which indicates password guess attack from a group of internal IP addresses 

```
Oct 31 17:28:43 my-vm-001 sshd[9619]: Bad protocol version identification 'GET / HTTP/1.1' from 10.114.160.169 port 46988
Oct 31 17:28:43 my-vm-001 sshd[9595]: Failed password for invalid user deploy from 10.114.160.83 port 56434 ssh2
Oct 31 17:28:43 my-vm-001 sshd[9595]: Connection closed by 10.114.160.83 port 56434 [preauth]
Oct 31 17:28:43 my-vm-001 sshd[9599]: Failed password for invalid user deploy from 10.114.160.79 port 56850 ssh2
Oct 31 17:28:43 my-vm-001 sshd[9606]: Failed password for invalid user dev from 10.114.160.70 port 57682 ssh2
Oct 31 17:28:43 my-vm-001 sshd[9616]: reprocess config line 50: Deprecated option RSAAuthentication
Oct 31 17:28:43 my-vm-001 sshd[9616]: Invalid user developer from 10.114.160.83 port 58930
Oct 31 17:28:43 my-vm-001 sshd[9616]: input_userauth_request: invalid user developer [preauth]
Oct 31 17:28:44 my-vm-001 sshd[9599]: Connection closed by 10.114.160.79 port 56850 [preauth]
Oct 31 17:28:44 my-vm-001 sshd[9606]: Connection closed by 10.114.160.70 port 57682 [preauth]
```

I ask myself 
  1. How to find all source IP addresses that are involved in this attack
  2. How to count by IP adressses

The obvious approach is 
  1. Use any TEXT Editor software or grep
  2. Search IP Address by Regular Expression "([0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3})" 
  3. Export to a file 
  4. Count it by Excel. need import in EXCEL first. (too much clicking... option to select)

Let's use ADX to make it work in one-shot. 

# Steps
1. Create table [securelog], with only one attribute message: string
  ```kql
  .create table securelog(message:string)
  ```
2. Upload secure log to storage account and container. Create Storage SAS token. 
3. Ingest secure log into table securelog from SAS token. 
  ```kql
  .ingest into table securelog(h'<replace with storage sas token in step 2>') with (format='psv')
  ```
4. Write query & Run
  ```kql
  securelog 
  | where message contains "Failed Password"
  | extend sourceip=tostring(extractall(@"([0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3})",message))
  | extend port =tostring(extractall(@"port ([0-9]{3,5})",message))
  | summarize count() by sourceip

    Result Set: (Name=Table_0)
          ----------------------------
          sourceip           | count_
          ----------------------------
          ["10.114.160.69"]  | 19
          ["10.114.160.72"]  | 17
          ["10.114.160.74"]  | 16
          ["10.114.160.77"]  | 13
          ["10.114.160.78"]  | 12
          ["10.114.160.71"]  | 12
          ["10.114.160.76"]  | 15
          ["10.114.160.85"]  | 16
          ["10.114.160.81"]  | 14
          ["10.114.160.80"]  | 16
          ["10.114.160.84"]  | 15
          ["10.114.160.75"]  | 16
          ["10.114.160.82"]  | 12
          ["10.114.160.73"]  | 10
          ["10.114.160.86"]  | 16
          ["10.114.160.79"]  | 16
          ["10.114.160.83"]  | 14
          ["10.114.160.70"]  | 15
          ----------------------------
```          
          
          
## Next challenge is 

How do I covert the timestamp in secure log to DATETIME field , then we can use it like datetime field. Here is my way, of course there are better ways, please feel free to comment and share

``` kql
securelog 
| where message contains "Failed Password"
| extend message1=replace_regex(message,'  ',' ')
| extend sourceip=tostring(extractall(@"([0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3})",message))
| extend month=split(message1,' ')[0] 
| extend day=split(message1,' ')[1] 
| extend times=split(message1,' ')[2] 
| extend timestamp=todatetime(strcat(day,' ',month,' 22 ',times))
| extend port =tostring(extractall(@"port ([0-9]{3,5})",message))
| project-away message1, month, day, times
| project timestamp, sourceip, port, message

timestamp	                  sourceip	        port	    message
2022-10-30 08:45:54.0000000	["10.114.160.69"]	["38873"]	Oct 30 08:45:54 my-vm-001 sshd[8020]: Failed password for invalid user admin from 10.114.160.69 port 38873 ssh2
2022-10-31 04:34:03.0000000	["10.114.160.72"]	["14371"]	Oct 31 04:34:03 my-vm-001 sshd[30378]: Failed password for invalid user internet from 10.114.160.72 port 14371 ssh2
2022-10-31 10:01:38.0000000	["10.114.160.72"]	["60254"]	Oct 31 10:01:38 my-vm-001 sshd[20621]: Failed password for root from 10.114.160.72 port 60254 ssh2
2022-10-31 10:01:40.0000000	["10.114.160.74"]	["33542"]	Oct 31 10:01:40 my-vm-001 sshd[20628]: Failed password for root from 10.114.160.74 port 33542 ssh2
2022-10-31 10:01:42.0000000	["10.114.160.72"]	["34682"]	Oct 31 10:01:42 my-vm-001 sshd[20638]: Failed password for root from 10.114.160.72 port 34682 ssh2
2022-10-31 10:01:45.0000000	["10.114.160.77"]	["36582"]	Oct 31 10:01:45 my-vm-001 sshd[20659]: Failed password for root from 10.114.160.77 port 36582 ssh2
<removed> result
```


# Use ADX to analyze random DNS log

Today, receive one DNS log which indicates DNS resolution time out, I want to convert the TIMESTAMP from AEDT to UTC and also get all DNS name list to create a DNSnamelist.txt to make a reproduce. 

```
19-Jan-2023 14:31:11.848 timed out resolving 'onedscolprdjpe03.japaneast.cloudapp.azure.com/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:26.873 timed out resolving '4316b.wpc.azureedge.net/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:28.670 timed out resolving 'onedscolprdjpe04.japaneast.cloudapp.azure.com/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:37.812 timed out resolving 'vmss-proxy-prod-australiaeast.australiaeast.cloudapp.azure.com/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:49.625 timed out resolving 'waws-prod-ml1-029-fca6.australiasoutheast.cloudapp.azure.com/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:52.045 timed out resolving 'api-cc-geo-skype.trafficmanager.net/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:53.370 timed out resolving 'agl-customer-mel-pt-api.azurewebsites.net/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:56.683 timed out resolving 'a-ups-presence9-prod-azsc.australiaeast.cloudapp.azure.com/A/IN': 168.63.129.16#53
19-Jan-2023 14:31:58.905 timed out resolving 'tm-aue-prod-adms-fe.trafficmanager.net/A/IN': 168.63.129.16#53

total 5000+ lines and timestamp is AEDT UTC+11
```

(Same approach), To better analyze the log, I use ADX to deal with DNS Log. Here is the query.

```kql
dnslog
| extend dns=split(message,' ')[5]
| extend dnsname=trim_start("'",tostring(split(dns,'/')[0]))
| extend TYPE=trim_start("'",tostring(split(dns,'/')[1]))
| extend DNSSERVER=split(message,' ')[6]
| extend year=trim_start('20',tostring(split(split(message,' ')[0],'-')[2]))
| extend month=split(split(message,' ')[0],'-')[1]
| extend day=split(split(message,' ')[0],'-')[0]
| extend hourtime=split(message,' ')[1]
| extend CTIME_UTC=todatetime(strcat(day,'-',month,'-',year,' ',hourtime,' AEDT')) // AST is UTC+3, ADET is UTC+11
| project CTIME_UTC, dnsname, TYPE, DNSSERVER, message
| where CTIME_UTC > datetime(2023-01-19 03:31:00.8480000) and CTIME_UTC < datetime(2023-01-19 03:32:00.8480000)
 
```
![image](./.image/dnslog_kusto.png?raw=true)

