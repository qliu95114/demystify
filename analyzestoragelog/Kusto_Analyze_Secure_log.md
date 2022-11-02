# Use Kusto to analyze the Linux secure log 

Today I receive a secure log which indidcate password guess attack from internal ip addresses 

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
  1. How to find all source ip address that involved the attack, 
  2. How to count those ip adressses. 

The obvious way is using any TEXT Editor software or grep, search by IP address by Regular Expression "([0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3})" and export to a file and count it by Excel.

Let's use Azure Data Explorer to make it work in one shot, assume you already setup [KustoFree](https://aka.ms/kustofree)

# Steps 
1. Create table securelogdemo , attribute message: string
  ```
  .create table securelog(message:string)
  ```
2. Upload secure log to storage account, container. Create Storage SAS token
3. Inject secure log into table securelog from storage account
  ```
  .ingest into table securelog(h'<replace with storage sas token>' 'with (format='psv')
  ```
4. Write query & Run
  ```
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




