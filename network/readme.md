# Index 

1. HOSTS : copy to c:\windows\system32\drivers\etc
1. r.*.cmd : handle VPN situation, if you some ip address could direct go to internet with ForceTunnel VPN, please r.exclude.cmd
1. [tshark_sample](./tshark_samples.md)
1. [NSG flow log to CSV](./convert-nsgflowlog2csv.ps1)
1. mount-azure-storage.ipynb, process-nsg-logs.ipynb. used for Azure Databrick to process NSG flow log 
1. [Pcap2Kusto](./pcap2kusto/pcap2kusto.ps1). This script converts one cap or pcap file to CSV format and can also convert all *.cap or *.pcap files in a folder to CSV files. It can be used with Kusto Emulator on the same machine or with a file share path. For Kusto Cluster, a storage container sas token can be provided to upload files. 
Table names are required, or the script will create one.
1. [mergecapfiles](./pcap2kusto/mergecapfiles.ps1). Merge network trace file under one folder 

