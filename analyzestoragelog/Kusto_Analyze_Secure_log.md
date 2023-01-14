# Use Kusto to analyze the Linux secure log 

Today I receive one secure log which indidcates password guess attack from a group of internal IP addresses 

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

Let's use Azure Data Explorer to make it work in oneshot, assume you already setup [KustoFree](https://aka.ms/kustofree)

# Steps 
1. Create table [securelog], with only one attribute message: string
  ```kql
  .create table securelog(message:string)
  ```
2. Upload secure log to storage account, container. Create Storage SAS token
3. Inject secure log into table securelog from storage account
  ```kql
  .ingest into table securelog(h'<replace with storage sas token>') with (format='psv')
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
          
          
# Next challenge is 

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




