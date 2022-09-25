# Today I am introducing a "free" way to analyze Azure Storage Account Access Log via ADX (Azure Data Explorer)

# Prepare the enviornment. 

1. Apply Free ADX cluster from [FreeCluster](https://aka.ms/kustofree). Everyone the planet has internet Access, and Microsoft Account would get one
1. [Enable and manage Azure Storage Analytics logs (classic)](https://learn.microsoft.com/en-us/azure/storage/common/manage-storage-analytics-logs?tabs=azure-portal)
1. [Azure Storage Explorer](https://azure.microsoft.com/en-us/products/storage/storage-explorer/)
1. [Kusto Explorer](https://aka.ms/ke)

# Knowledge 

1. Azure Storage Account basic, how to create SAS token
1. Kusto Explorer

# Put into Action

1. Generate traffic to access your storage account
1. You will see below in Storage Explorer , create SAS token at container $log level, 
   ![Storage Explorer view logs](./image/image1.png)
1. Create a list of SAS URL
```
https://<StorageAccountURL>/$log/xxx/000001.log?sv=2021-04-10&st=2022-09-21T13%3A56%3A59Z&se=2022-09-30T13%3A56%3A00Z&sr=c&sp=rl&sig=xxxxxxxxxxxxxxxxxxxxxxxxxx%3D'
https://<StorageAccountURL>/$log/xxx/000002.log?sv=2021-04-10&st=2022-09-21T13%3A56%3A59Z&se=2022-09-30T13%3A56%3A00Z&sr=c&sp=rl&sig=xxxxxxxxxxxxxxxxxxxxxxxxxx%3D'
...
https://<StorageAccountURL>/$log/xxx/00000x.log?sv=2021-04-10&st=2022-09-21T13%3A56%3A59Z&se=2022-09-30T13%3A56%3A00Z&sr=c&sp=rl&sig=xxxxxxxxxxxxxxxxxxxxxxxxxx%3D'
```
1. Use ADX Wizard [Link](https://dataexplorer.azure.com/oneclick) -> Ingress data from Blob
1. Use Kusto Explorer, and add the Kusto Endpoint you get from [FreeCluster](https://aka.ms/kustofree)

# Kusto Explorer action to import storage log as table

```
.drop table storagelog
 
.create table ['storagelog']  (['version-number']:real, ['request-start-time']:datetime, ['operation-type']:string, ['request-status']:string, ['http-status-code']:long, ['end-to-end-latency-in-ms']:long, ['server-latency-in-ms']:long, ['authentication-type']:string, ['requester-account-name']:string, ['owner-account-name']:string, ['service-type']:string, ['request-url']:string, ['requested-object-key']:string, ['request-id-header']:guid, ['operation-count']:long, ['requester-ip-address']:string, ['request-version-header']:datetime, ['request-header-size']:long, ['request-packet-size']:long, ['response-header-size']:long, ['response-packet-size']:long, ['request-content-length']:long, ['request-md5']:string, ['server-md5']:string, ['etag-identifier']:string, ['last-modified-time']:datetime, ['conditions-used']:string, ['user-agent-header']:string, ['referrer-header']:string, ['client-request-id']:guid)
 
.ingest into table ['storagelog'] (h'https://<StorageAccountURL>/$log/xxx/000001.log?sv=2021-04-10&st=2022-09-21T13%3A56%3A59Z&se=2022-09-30T13%3A56%3A00Z&sr=c&sp=rl&sig=xxxxxxxxxxxxxxxxxxxxxxxxxx%3D'') with (format='scsv')
.ingest into table ['storagelog'] (h'https://<StorageAccountURL>/$log/xxx/000002.log?sv=2021-04-10&st=2022-09-21T13%3A56%3A59Z&se=2022-09-30T13%3A56%3A00Z&sr=c&sp=rl&sig=xxxxxxxxxxxxxxxxxxxxxxxxxx%3D'') with (format='scsv')
...
.ingest into table ['storagelog'] (h'https://<StorageAccountURL>/$log/xxx/00000x.log?sv=2021-04-10&st=2022-09-21T13%3A56%3A59Z&se=2022-09-30T13%3A56%3A00Z&sr=c&sp=rl&sig=xxxxxxxxxxxxxxxxxxxxxxxxxx%3D'') with (format='scsv')
```

# Play with the Magic in Kusto Explorer 

```
//get log start /end time
storagelog | summarize starttime=min(['request-start-time']), endtime=max(['request-start-time'])

//get log count summarize by 5 minutes
storagelog
| summarize count() by bin(['request-start-time'],5m) 
```




