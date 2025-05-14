 [[_TOC_]]

# Using Tshark to dump Packet details into TEXT format

Every day while I am working with network traces, there are many scenarios: 
- Sharing the trace analysis details with colleagues can be done using screenshots (PrtScr or FastStone capture), but this is not very friendly for email or MarkDown editing. 
- Working with very large PCAP files to gain useful insights can be slow, as filters in Wireshark take time to process. 
- Working with many (1000+) PCAP files to apply the same filter to gain useful insights can be difficult; combining the PCAP files into one file might help, but this can lead to the second limitation mentioned above. 
- Working with trace and try to generate insight of request per seconds. 

Today, I would like to introduce some ideas to leverage tshark for working with PCAP file(s).

## Sample 1 - Expand TCP Details of one specific Frame
``` bash
C:\temp>"C:\Program Files\Wireshark\tshark.exe" -r d:\temp\mytrace.pcapng -V -O tcp frame.number == 5 
Frame 5: 54 bytes on wire (432 bits), 54 bytes captured (432 bits) on interface \Device\NPF_{5E9AC1A3-4E57-4A03-A87B-3A41C71B859F}, id 0
Ethernet II, Src: 82:04:5f:c1:42:64 (82:04:5f:c1:42:64), Dst: IntelCor_7a:90:b8 (40:1c:83:7a:90:b8)
Internet Protocol Version 4, Src: 100.45.55.66, Dst: 172.20.10.5
Transmission Control Protocol, Src Port: 443, Dst Port: 51336, Seq: 1732514733, Ack: 1176144938, Len: 0
    Source Port: 443
    Destination Port: 51336
    [Stream index: 0]
    [Conversation completeness: Complete, NO_DATA (23)]
    [TCP Segment Len: 0]
    Sequence Number: 1732514733
    [Next Sequence Number: 1732514733]
    Acknowledgment Number: 1176144938
    0101 .... = Header Length: 20 bytes (5)
    Flags: 0x010 (ACK)
        000. .... .... = Reserved: Not set
        ...0 .... .... = Accurate ECN: Not set
        .... 0... .... = Congestion Window Reduced: Not set
        .... .0.. .... = ECN-Echo: Not set
        .... ..0. .... = Urgent: Not set
        .... ...1 .... = Acknowledgment: Set
        .... .... 0... = Push: Not set
        .... .... .0.. = Reset: Not set
        .... .... ..0. = Syn: Not set
        .... .... ...0 = Fin: Not set
        [TCP Flags: ·······A····]
    Window: 63
    [Calculated window size: 64512]
    [Window size scaling factor: 1024]
    Checksum: 0x37fa [unverified]
    [Checksum Status: Unverified]
    Urgent Pointer: 0
    [Timestamps]
        [Time since first frame in this TCP stream: 0.143940000 seconds]
        [Time since previous frame in this TCP stream: 0.074449000 seconds]
    [SEQ/ACK analysis]
        [This is an ACK to the segment in frame: 4]
        [The RTT to ACK the segment was: 0.074449000 seconds]
        [iRTT: 0.068990000 seconds]
```

## Sample 2 - list conversation view by ip 
``` bash
C:\temp>"C:\Program Files\Wireshark\tshark.exe" -qz conv,ip -r mytrace.pcap
================================================================================
IPv4 Conversations
Filter:<No Filter>
                                               |       <-      | |       ->      | |     Total     |    Relative    |   Duration   |
                                               | Frames  Bytes | | Frames  Bytes | | Frames  Bytes |      Start     |              |
25.86.198.43         <-> 10.1.214.138               0 0 bytes    242522 48 MB      242522 48 MB         0.000000000       348.5403
100.107.156.220      <-> 10.67.88.80                0 0 bytes     96480 19 MB       96480 19 MB         0.010150000       346.0712
13.75.127.39         <-> 10.20.78.83                0 0 bytes     76136 15 MB       76136 15 MB         0.072910000       348.4674
13.75.127.39         <-> 10.20.78.82                0 0 bytes     69681 13 MB       69681 13 MB         0.014969000       348.5132
172.17.55.129        <-> 172.29.59.138          19981 5115 kB     19998 5119 kB     39979 10 MB        23.738512000       128.8738
10.240.38.51         <-> 172.29.59.138           3883 733 kB       2910 484 kB       6793 1218 kB       0.477082000       347.8479
10.240.42.159        <-> 172.29.59.138           3129 590 kB       3278 608 kB       6407 1199 kB       0.430842000       345.4340
172.29.59.138        <-> 10.240.43.76            2326 447 kB       3540 703 kB       5866 1151 kB       2.569396000       345.8527
10.240.43.44         <-> 172.29.59.138           3577 706 kB       2077 392 kB       5654 1099 kB       0.010150000       348.5180
10.240.38.64         <-> 172.29.59.138           3557 702 kB       2038 394 kB       5595 1097 kB       0.756101000       347.6669
10.240.43.2          <-> 172.29.59.138           2760 553 kB       2673 519 kB       5433 1072 kB       0.240716000       347.4738
10.240.38.37         <-> 172.29.59.138           3092 586 kB       2011 389 kB       5103 976 kB        0.456899000       346.8406
10.240.38.45         <-> 172.29.59.138           2912 576 kB       1990 376 kB       4902 953 kB        0.398092000       347.6743
10.240.43.28         <-> 172.29.59.138           2826 557 kB       2041 396 kB       4867 954 kB        0.014776000       348.4651
10.240.42.22         <-> 172.29.59.138           2298 436 kB       2472 469 kB       4770 906 kB        0.170880000       348.0568
===================================================================================
``` 

## Sample 3 - list conversation view by tcp
``` bash
C:\temp>"C:\Program Files\Wireshark\tshark.exe" -qz conv,tcp -r mytrace.pcap
================================================================================
TCP Conversations
Filter:<No Filter>
                                                           |       <-      | |       ->      | |     Total     |    Relative    |   Duration   |
                                                           | Frames  Bytes | | Frames  Bytes | | Frames  Bytes |      Start     |              |
10.240.42.159:57628        <-> 172.29.59.138:8002            1592 300 kB       1874 342 kB       3466 643 kB        0.430842000       345.4340
10.240.43.78:54060         <-> 172.29.59.138:8002            1476 281 kB       1543 258 kB       3019 540 kB        0.708382000       345.1964
10.240.43.58:59499         <-> 172.29.59.138:8002            1419 270 kB       1447 279 kB       2866 550 kB        0.485558000       347.5795
10.240.38.45:58624         <-> 172.29.59.138:8001            1317 247 kB       1536 288 kB       2853 535 kB        3.999007000       342.4981
10.240.43.44:65288         <-> 172.29.59.138:8001            1253 237 kB       1435 269 kB       2688 506 kB        0.010150000       346.6484
10.240.43.76:50684         <-> 172.29.59.138:8001            1150 218 kB       1212 233 kB       2362 452 kB        3.963122000       335.0071
10.240.43.45:50525         <-> 172.29.59.138:8002            1030 190 kB       1304 213 kB       2334 403 kB        0.625032000       345.0956
10.240.38.26:60321         <-> 172.29.59.138:8001            1128 214 kB       1175 186 kB       2303 400 kB        0.754315000       345.6482
10.240.38.26:59389         <-> 172.29.59.138:8001            1123 213 kB       1164 183 kB       2287 397 kB        0.615720000       344.7861
10.240.38.43:55250         <-> 172.29.59.138:8001            1098 207 kB       1171 226 kB       2269 433 kB        2.897450000       343.7423
10.240.43.73:53970         <-> 172.29.59.138:8002            1108 210 kB       1145 217 kB       2253 428 kB        0.320825000       320.2380
10.240.38.72:51298         <-> 172.29.59.138:8002            1013 192 kB       1058 205 kB       2071 398 kB      145.155329000       202.7795
================================================================================

```

## Sample 4 - Convert PCAP to CSV, ingress to ADX (Kusto) to analyze trace in fast fashion

For big trace analyze, use Azure Data Explorer (aka. kusto) is good way to speed up our analyze. To do that
1. (tshark) Export trace to CSV 
1. (kusto) create table in ADX
1. (kusto) Ingress CSV in step 1 to ADX

### Best Practice of handling Trace in Azure Data Explorer
|Scenarios| KQL Sample|
|-|-|
|Datetime|\| extend aa=tolong(replace_string(frametime,'.',''))/1000 <br>\| extend TT=unixtime_microseconds_todatetime(aa)|
|Delta-Time|\| order by TT asc // sort by timestamp<br>//add you filter<br>\| extend  delta_in_ms=toreal(datetime_diff('nanosecond',TT, prev(TT)))/1000000 //get DeltaTimeDisplayed in Kusto Way<br>\| project  delta_in_ms
|Encap Packets|\| extend SourceCA=tostring(split(Source,',')[countof(Source,',')])//if this is encap traffic, get inner source ip address<br>\| extend DestCA=tostring(split(Destination,',')[countof(Destination,',')])//if this is encap traffic, get inner dest ip address<br>\| extend SourcePA=tostring(split(Source,',')[countof(Source,',')-1])//if this is encap traffic, get outer Source Ip<br>\| extend DestPA=tostring(split(Destination,',')[countof(Destination,',')-1])//if this is encap traffic, get outer Dest Ip<br>\| extend ipidinnner=split(ipid,',')[countof(ipid,',')] //if this is encap traffic, get inner ipid<br>\| extend ipTTLInner=split(ipTTL,',')[countof(ipTTL,',')] //if this is encap traffic, get inner ipTTL|
|Time shift|\| extend TT=datetime_add('second', -19, TT)|
|Conversation|\|extend flowhash=hash(IPToInt(SourceCA)+IPToInt(DestCA))+hash(toint(tcpsrcport)*toint(tcpdstport))|

Here is my favorite fields commonly used when analyze TCP/UDP network trace, Encap Trace file are supported. 

1. (tshark) Export trace to csv , Fields selected
``` bash 
"c:\program files\wireshark\tshark" -r my.pcapng -T fields -e frame.number -e frame.time_epoch -e frame.time_delta_displayed -e ip.src -e ip.dst -e ip.id -e _ws.col.Protocol -e tcp.seq -e tcp.ack -e frame.len -e tcp.srcport -e tcp.dstport -e udp.srcport -e udp.dstport -e tcp.analysis.ack_rtt -e frame.protocols -e _ws.col.Info -e eth.src -e eth.dst -e ipv6.src -e ipv6.dst -e ip.proto -e dns.id -E header=y -E separator=, -E quote=d > my.pcapng.csv
```

ADX (Kusto) create table and ingress from CSV to table 

Import ADX might failure due to Wirehsark parser, need disable a few protocols to get clean output in Field "Info" 
Recommended Protocol to disable, IRC , RESP (Redis)

``` kql
.drop table trace  //

.create table trace (framenumber:long,frametime:string,DeltaDisplayed:string,Source:string,Destination:string,ipid:string,Protocol:string,tcpseq:string,tcpack:string,Length:int,tcpsrcport:int,tcpdstport:int,udpsrcport:int,udpdstport:int,tcpackrtt:string,frameprotocol:string,Info:string,ethsrc:string,ethdst:string,SourceV6:string,DestinationV6:string,ipProtocol:string,dnsid:string)

.ingest into table trace (@"c:\temp\my.pcapng.csv") with (format='csv',ignoreFirstRecord=true)  // For Local Kusto Emulator

.ingest into table trace (@"<SAS URL to file on Azure Blob Storage>") with (format='csv',ignoreFirstRecord=true)  // For Azure Data Explorer cluster
```

Sample query 
1. covert Epoch time to UTC readable format
1. Filter data 

``` kql
//convert epoch time to UTC display time with Seconds, handle flowhash
let IPToInt = (ip:string) {  // define IPToInt function
    toint(split(ip, '.')[0]) * 256 * 256 * 256 +
    toint(split(ip, '.')[1]) * 256 * 256 +
    toint(split(ip, '.')[2]) * 256 +
    toint(split(ip, '.')[3])};
trace 
| extend aa=tolong(replace_string(frametime,'.',''))/1000
| extend TT=unixtime_microseconds_todatetime(aa)
| extend SourceCA=tostring(split(Source,',')[countof(Source,',')])//return inner src ip address
| extend DestCA=tostring(split(Destination,',')[countof(Destination,',')])//return inner dest ip address
| extend SourcePA=tostring(split(Source,',')[countof(Source,',')-1])//return outer src ip address
| extend DestPA=tostring(split(Destination,',')[countof(Destination,',')-1])//return outer dest ip address
| extend ipidinner=split(ipid,',')[countof(ipid,',')] //return inner ipid
| extend ipTTLInner=split(ipTTL,',')[countof(ipTTL,',')] //return inner ipTTL
| extend ethsrci=tostring(split(ethsrc,',')[countof(ethsrc,',')]) //return inner src eth.addr
| extend ethdsti=tostring(split(ethdst,',')[countof(ethdst,',')]) //return inner dest eth.addr
| extend ipProtocoli=tostring(split(ipProtocol,',')[countof(ipProtocol,',')]) //return inner ipProtocol 
| project-away framenumber, frametime, DeltaDisplayed, aa //remove unused field
| extend flowhash=case(   //calc the flowhash based on the ipProtocol value icmp/udp/tcp , only take the inner protocol
ipProtocoli=='6', hash(IPToInt(SourceCA)+IPToInt(DestCA))+hash(toint(tcpsrcport)*toint(tcpdstport)),
ipProtocoli=='17', hash(IPToInt(SourceCA)+IPToInt(DestCA))+hash(toint(udpsrcport)*toint(udpdstport)),
ipProtocoli=='1',hash(IPToInt(SourceCA)+IPToInt(DestCA)),
0
) 
| project-reorder flowhash, TT, SourcePA, DestPA, SourceCA, DestCA, ethsrci, ethdsti, ipProtocoli, Protocol,ipidinner, ipTTLInner, tcpseq, tcpack, tcpFlags,Length, Info, tcpsrcport, tcpdstport, udpsrcport, udpdstport
| take 20  //get 20 record from top

//to get deltatime displayed, this is more useful when view by conversation(flowhash), so move to second part of the function
//| order or flowhah or filter by flowhas first
| order by TT asc // sort by timestamp
| extend  delta_in_ms=toreal(datetime_diff('nanosecond',TT, prev(TT)))/1000000  //get DeltaTimeDisplayed in Kusto Way
| project flowhash,TT,delta_in_ms, SourceCA, DestCA, ipidinnner,ipTTLInner, Protocol,tcpseq, tcpack, Length, Info, tcpsrcport, tcpdstport, tcpFlags//,ethsrc, ethdst, frameprotocol
| take 20  //get 20 record from top

//to take last 10 record
| order by TT desc | take 10 | order by TT asc // take last 10 records

//decode Azure Service Endpoint or Private Link ipv6 ipaddress
//SourceV6 and DestinationV6 has ipv6 address, let's use the following query to decode that ip address to Sourcev4decode, Destv4decode
| extend ip_a=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(SourceV6,':')[6]))))
| extend ip_b=toint(strcat('0x',tostring(split(SourceV6,':')[6])))-ip_a*256
| extend ip_c=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(SourceV6,':')[7]))))
| extend ip_d=toint(strcat('0x',tostring(split(SourceV6,':')[7])))-ip_c*256
| extend Sourcev4decode=strcat(tostring(ip_a),'.',tostring(ip_b),'.',tostring(ip_c),'.',tostring(ip_d))
| extend Sourcev4decode=iff(Sourcev4decode == '...',SourceV6,Sourcev4decode)
| project-away ip_a, ip_b, ip_c , ip_d
| extend ip_a=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(DestinationV6,':')[6]))))
| extend ip_b=toint(strcat('0x',tostring(split(DestinationV6,':')[6])))-ip_a*256
| extend ip_c=toint(strcat('0x',trim_end('[a-z0-9]{2}',tostring(split(DestinationV6,':')[7]))))
| extend ip_d=toint(strcat('0x',tostring(split(DestinationV6,':')[7])))-ip_c*256
| extend Destv4decode=strcat(tostring(ip_a),'.',tostring(ip_b),'.',tostring(ip_c),'.',tostring(ip_d))
| extend Destv4decode=iff(Destv4decode == '...',DestinationV6,Destv4decode)
| project-away ip_a, ip_b, ip_c , ip_d

//For improved query performance, it's recommended to first create a new table with hash values. This allows you to work directly with the hashed table, simplifying complex queries.
.set-or-replace trace_hash <| (use the first table above)
```
Result:
```
framenumber	TT	DeltaDisplayed	Source	Destination	ipid	Protocol	tcpseq	tcpack	Length	Info	tcpsrcport	tcpdstport	udpdstport	udpsrcport	ethsrc	ethdst	frameprotocol
1	2022-11-04 06:13:53.6285160	0.000000000	10.115.68.111	122.111.111.111	0xb3f6	6	3443987890	0	66	54010 → 443 [SYN] Seq=3443987890 Win=64240 Len=0 MSS=1460 WS=256 SACK_PERM	54010	443			c0:fb:f9:c6:dc:bc	68:3a:1e:74:ee:a0	eth:ethertype:ip:tcp
2	2022-11-04 06:13:53.6692370	0.040721000	122.111.111.111	10.115.68.111	0x0000	6	3280391636	3443987891	66	443 → 54010 [SYN, ACK] Seq=3280391636 Ack=3443987891 Win=64240 Len=0 MSS=1360 SACK_PERM WS=1024	443	54010			68:3a:1e:74:ee:a0	c0:fb:f9:c6:dc:bc	eth:ethertype:ip:tcp
3	2022-11-04 06:13:53.6694950	0.000258000	10.115.68.111	122.111.111.111	0xb3f7	6	3443987891	3280391637	54	54010 → 443 [ACK] Seq=3443987891 Ack=3280391637 Win=131840 Len=0	54010	443			c0:fb:f9:c6:dc:bc	68:3a:1e:74:ee:a0	eth:ethertype:ip:tcp
4	2022-11-04 06:13:53.6805270	0.011032000	10.115.68.111	122.111.111.111	0xb3f8	6	3443987891	3280391637	571	Client Hello	54010	443			c0:fb:f9:c6:dc:bc	68:3a:1e:74:ee:a0	eth:ethertype:ip:tcp:tls
5	2022-11-04 06:13:53.7203860	0.039859000	122.111.111.111	10.115.68.111	0x71f7	6	3280391637	3443988408	62	443 → 54010 [ACK] Seq=3280391637 Ack=3443988408 Win=64512 Len=0	443	54010			68:3a:1e:74:ee:a0	c0:fb:f9:c6:dc:bc	eth:ethertype:ip:tcp
6	2022-11-04 06:13:53.7224630	0.002077000	122.111.111.111	10.115.68.111	0x71f8	6	3280391637	3443988408	1384	Server Hello	443	54010			68:3a:1e:74:ee:a0	c0:fb:f9:c6:dc:bc	eth:ethertype:ip:tcp:tls

```

### Tips
To work with list of cap files, let's create one batch file 
``` bash
* following command must run Windows Command Prompt not Powershell
cd d:\temp
for /f "delims=" %a in ('dir /b /o *.pcap') do "c:\program files\wireshark\tshark" -r "%a" -T fields -e frame.number -e frame.time_epoch -e frame.time_delta_displayed -e ip.src -e ip.dst -e ip.id -e _ws.col.Protocol -e tcp.seq -e tcp.ack -e frame.len -e tcp.srcport -e tcp.dstport -e udp.srcport -e udp.dstport -e tcp.analysis.ack_rtt -e frame.protocols -e _ws.col.Info -e eth.src -e eth.dst -e ipv6.src -e ipv6.dst -e ip.proto -E header=y -E separator=, -E quote=d > "%~na.csv"

rem before process

D:\temp>dir *.cap
 Volume in drive D is 1-DATA
 Volume Serial Number is DE8A-D932

 Directory of D:\temp

2022-11-09  11:33 AM       209,708,373 NetworkTraces(1).cap
2022-11-09  11:33 AM       209,702,450 NetworkTraces(2).cap
2022-11-09  11:33 AM       209,710,439 NetworkTraces(3).cap
2022-11-09  11:33 AM       209,715,136 NetworkTraces(4).cap
2022-11-09  11:33 AM       209,714,430 NetworkTraces(5).cap
2022-11-09  11:33 AM        29,736,420 NetworkTraces(6).cap
2022-11-09  11:33 AM       209,702,622 NetworkTraces.cap
               7 File(s)  1,287,989,870 bytes
               0 Dir(s)  569,877,078,016 bytes free

rem After process

D:\temp>dir NetworkTrace*.*
 Volume in drive D is 1-DATA
 Volume Serial Number is DE8A-D932

 Directory of D:\temp

2022-11-09  11:33 AM       209,708,373 NetworkTraces(1).cap
2022-11-13  10:11 PM        73,217,373 NetworkTraces(1).cap.csv
2022-11-09  11:33 AM       209,702,450 NetworkTraces(2).cap
2022-11-13  10:12 PM        69,142,598 NetworkTraces(2).cap.csv
2022-11-09  11:33 AM       209,710,439 NetworkTraces(3).cap
2022-11-13  10:12 PM        75,541,769 NetworkTraces(3).cap.csv
2022-11-09  11:33 AM       209,715,136 NetworkTraces(4).cap
2022-11-13  10:12 PM        75,263,490 NetworkTraces(4).cap.csv
2022-11-09  11:33 AM       209,714,430 NetworkTraces(5).cap
2022-11-13  10:12 PM        73,566,784 NetworkTraces(5).cap.csv
2022-11-09  11:33 AM        29,736,420 NetworkTraces(6).cap
2022-11-13  10:12 PM        10,937,967 NetworkTraces(6).cap.csv
2022-11-09  11:33 AM       209,702,622 NetworkTraces.cap
2022-11-13  10:13 PM        72,236,137 NetworkTraces.cap.csv
              14 File(s)  1,737,895,988 bytes
               0 Dir(s)  569,877,078,016 bytes free

```

## Sample 5 - Detect 1s delay TCP SYN - TCP SYN/ACK for port 6379 traffic, Data source is 1000+ trace files 

I got into a situation today where I had to review over 1000 pcap files to detect a problem where the TCP 3-way handshake was taking longer than 1 second.

To detect if a TCP 3-way handshake is taking longer than 1 second, I am using a FILTER.

`tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1`

To make the filter work for 1,000+ files, let's use a batch file

``` bash
cd c:\tracefile
for /f "delims=" %a in ('dir /b /o *.pcap') do "c:\program files\wireshark\tshark.exe" -r "c:\tracefile\%a" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"
```

Result is promising....

``` bash
d:\tracefile>"c:\program files\wireshark\tshark.exe" -r "c:\tracefile\file_16_43_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_44_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"
22808 2023-01-13 16:44:47.160183 0.000000 10.227.8.192 → 10.227.6.87  0x0000 (0),0x0100 (256),0x0000 (0) TCP 2945986252 1537613497 1.035904000 154 6379 → 41990 [SYN, ACK] Seq=2945986252 Ack=1537613497 Win=43440 Len=0 MSS=1418 SACK_PERM TSval=2115729317 TSecr=842724217 WS=512
22810 2023-01-13 16:44:47.160438 0.000255 10.227.4.160 → 10.227.6.87  0x0000 (0),0x0100 (256),0x0000 (0) TCP 1741601663 3024541421 1.036066000 154 6379 → 38444 [SYN, ACK] Seq=1741601663 Ack=3024541421 Win=43440 Len=0 MSS=1418 SACK_PERM TSval=3755097511 TSecr=3102397576 WS=512

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_45_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_46_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_47_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"
```

We can conclude that in c:\tracefile\file_16_44_00.pcap, there are two "problematic" streams. Then, we can open the exact PCAP file (\file_16_44_00.pcap) and look at it in detail using Wireshark to analyze what the issue is.
```
10.227.8.192 → 10.227.6.87   6379 → 41990 [SYN, ACK] is taking 1.03590400 to response
10.227.4.160 → 10.227.6.87   6379 → 38444 [SYN, ACK] is taking 1.03606600 to response 
```

## Sample 6 － could we trust AB(AppacheBench) requests per second?

Today, we have received complaints that the user reported that the Apache Bench (AB) reported requests per second (RPS) below system limitations, but they were still throttled. 

In order to compare the AB results and see where things went wrong, I researched the source code of AB. I found that its RPS calculation is simply the total number of requests divided by the time taken for the tests (5000000 / 280 = 17857). This does not accurately convey the number of requests sent out every second, and can lead to misguiding analysis in modern or cloud environments.

``` bash
root@mymachine:~# ab -n 5000000 -c 500 -H "connection:close" http://10.6.0.4:80/

Time taken for tests:   280.039 seconds
Complete requests:      5000000
Requests per second:    17854.66 [#/sec] (mean) 
Time per request:       28.004 [ms] (mean) 
```

I requested that the team do a tcpdump, which resulted in a 4GB file. After converting to CSV, we had a 12GB file, which we sent to ADX. This provided us with the details we needed to investigate.
```kql
trace
| extend aa=tolong(replace_string(frametime,'.',''))/1000
| extend TT=unixtime_microseconds_todatetime(aa)
| extend SourceCA=tostring(split(Source,',')[-1])//if this is encap traffic, get inner ip addres only
| extend DestCA=tostring(split(Destination,',')[-1])//if this is encap traffic, get inner ip addres only
| extend ipidinnner=tostring(split(ipid,',')[-1]) //if this is encap traffic, get inner ipid only
| where tcpdstport == "80"
| where Source == "10.6.0.8"
| where tcpack == 0
| project TT,DeltaDisplayed, SourceCA, DestCA, ipidinnner, Protocol,tcpseq, tcpack, Length, Info, tcpsrcport, tcpdstport, udpdstport, udpsrcport//,ethsrc, ethdst, frameprotocol
| summarize count() by bin(TT,1s) | render timechart  
```
![image](./.image/ab.png?raw=true)

## Sample 7 - Use tshark to take rolling capture, host IP Filter -f "host x.x.x.x"

For long run capture, we can use rolling capture. the following sample will take 100 capture files and each file is set to 200MB, you can also include filter to furthe reduce the scope of the trace file

```bash
C:\temp>d:\Wireshark\tshark -D
1. \Device\NPF_{DC4266CC-D150-485B-AF26-CE59D246BD49} (Ethernet 4)
2. \Device\NPF_{D8591B22-E79C-4AD7-B62A-13E917469A6D} (Ethernet)

Enable tshark capture. Rolling tracking 
C:\temp>d:\wireshark\tshark -i 2 -n -b filesize:204800 -w "C:\temp\%COMPUTERNAME%.pcap" -b files:100 -s 128

-i interface id
-b filesize:204800 (max size per file : 200MB)
-b files:100  (max files: 100)
-s 128   packet lenght, take 128 including eth header. 

Enable tshark capture. Rolling tracking 
C:\temp>d:\wireshark\tshark -i 1 -n -b filesize:204800 -w "C:\temp\%COMPUTERNAME%.pcap" -b files:100 -s 128 -f "host 8.8.4.4"
```

## Sample 8 - Reduce file size - Truncate packet lengths

If you have a massive Wireshark capture, and you are struggling to process it due to its sheer size, you can use editcap.exe (which lives in your `C:\Program Files\Wireshark` folder) to truncate the individual packets, leaving only the necessary header data. Note that this is *generally* 64 bytes for general TCP/UDP traffic, but can be more if you are looking at encapsulated packets, etc. 

The `-s` parameter allows you to select your snaplength. Here is the format:

`editcap.exe -s <snaplength> <infile> <outfile>`

Real world example:

`C:\Program Files\Wireshark> .\editcap.exe -s 128 C:\Downloads\mycap.pcap C:\Downloads\mycap-snaplen128.pcap`

This turned one 3.6GB file `C:\Downloads\mycap.pcap` (3,850,030 total packets) into a 350MB file `C:\Downloads\mycap-snaplen128.pcap`.

More on editcap.exe can be found here: [editcap(1) Manual Page](https://www.wireshark.org/docs/man-pages/editcap.html)

## Sample 9 - Split large capture file with fix number of packets per file

``` bash
editcap.exe -c <number of packets per file> C:\path-to\OriginalFile.pcapng C:\path-to\NewFile.pcapng

rem split one file
editcap.exe -c 1500000 C:\path-to\OriginalFile.pcapng C:\path-to\NewFile.pcapng

rem split all files under one folder
for /f "delims=" %a in ('dir /b /o *.pcap') do "C:\program files\wireshark\editcap" -c 1500000 "%a" "split\%a"
```

Wireshark will append a suffix in the format of -nnnnn_YYYYMMDDHHMMSS.

nnnnn starts at 00000 and increments for each file
YYYYMMDDHHMMSS is the timestamp of the first packet in the new file

## Sample 10 - Find out all ICMP traffic from a 1000+ (459GB) trace file and analyze it.

I found myself in a situation today where I had to review over 1002 pcap files (total 459GB) to review ICMP traffic."
I hope that helps! Let me know if you have any other questions.

``` bash
rem - for one file 
"c:\Program Files\Wireshark\tshark.exe" -r tracefile001.pcap -Y "icmp" -w icmp\tracefile001.icmp.pcap
"c:\Program Files\Wireshark\tshark.exe" -r tracefile001.pcap -2R "icmp" -w icmp\tracefile001.icmp.pcap

rem - for all files
for /f "delims=" %a in ('dir /b /o *.pcap') do "c:\program files\wireshark\tshark.exe" -r "%a" -Y "icmp" -w "icmp\%~na.icmp.pcap"
```

## Sample 11A - Find out all DNS NoResponse from trace , assume you already import Network Trace to Kusto

```kql
trace
| where Protocol == 'DNS' and udpdstport == 53
//| where dnsid contains "0xb4d9"// and udpsrcport == '43815'
| extend aa=tolong(replace_string(frametime,'.',''))/1000
| extend TT=unixtime_microseconds_todatetime(aa   )
| extend SourceCA=tostring(split(Source,',')[countof(Source,',')])//if this is encap traffic, get inner ip addres only
| extend DestCA=tostring(split(Destination,',')[countof(Destination,',')])//if this is encap traffic, get inner ip addres only
| extend ipidinnner=tostring(split(ipid,',')[countof(ipid,',')]) //if this is encap traffic, get inner ipid only
| extend ipTTLInner=tostring(split(ipTTL,',')[countof(ipTTL,',')]) //if this is encap traffic, get inner ipTTL only
| extend DeviceIp=tostring(split(Source,',')[0])//if this is encap traffic, get inner ip addres only
| order by TT asc // sort by timestamp
| extend  delta_in_ms=toreal(datetime_diff('nanosecond',TT, prev(TT)))/1000000  //get DeltaTimeDisplayed in Kusto Way
| project TT,delta_in_ms, DeviceIp,SourceCA, DestCA, ipidinnner,ipTTLInner, Protocol, Length, Info, dnsid, udpdstport, udpsrcport//,ethsrc, ethdst, frameprotocol
//| distinct SourceCA, DestCA, dnsid, udpdstport, udpsrcport//, udpsrcport
| join kind=leftouter (trace 
| where Protocol == 'DNS' and udpsrcport == 53
| extend SourceCA=tostring(split(Source,',')[countof(Source,',')])//if this is encap traffic, get inner ip addres only
| extend DestCA=tostring(split(Destination,',')[countof(Destination,',')])//if this is encap traffic, get inner ip addres only
| distinct SourceCA, DestCA, dnsid, udpdstport, udpsrcport
| extend Paired="True"
) on $left.SourceCA==$right.DestCA and $left.dnsid==$right.dnsid and $left.udpdstport==$right.udpsrcport and $left.udpsrcport==$right.udpdstport
| project-away SourceCA1, DestCA1, dnsid1, udpdstport1, udpsrcport1
| where isempty(Paired)

```
![image](./.image/kql_dnsquery_noresponse.png?raw=true)

## Sample 11B - Find out all DNS NoResponse from trace , assume you already import Network Trace to Kusto

```kql
trace
| where Protocol == 'DNS' and (Source == '168.63.129.16')
| project frametime, Source, Destination, ipid, Protocol, Length, Info, udpdstport, udpsrcport, dnsid
| extend FQDN = extract("([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})", 1, Info)| where isnotempty(FQDN) //extract FQDN from Info
| summarize count() by FQDN, ipid, udpdstport, Length, dnsid //list all DNS reply packet with dnsid, ipid, fqdn
| join kind=rightanti (trace   //right anti join to get all DNS request without response
| where Protocol == 'DNS' and (Destination == '168.63.129.16')
| extend FQDN = extract("([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})", 1, Info)| where isnotempty(FQDN)
| project frametime, Source, Destination, ipid, Protocol, Length, Info, udpdstport, udpsrcport, dnsid
| extend FQDN = extract("([a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})", 1, Info)) on dnsid, $left.FQDN==$right.FQDN, $left.udpdstport==$right.udpsrcport
| extend aa=tolong(replace_string(frametime,'.',''))/1000
| extend TT=unixtime_microseconds_todatetime(aa)
| order by TT asc // sort by timestamp
| project TT,Source, Destination, ipid, Protocol,Length, FQDN, dnsid,  udpdstport, udpsrcport, Info
| summarize count() by bin(TT,1s)| render timechart
```
![image](./.image/kql_dnsquery_noresponse2.png?raw=true)

## Sample 12 - Handle a corrupt capture(cut-in-middle) file

Handle a corrupt capture(cut-in-middle) file and extract the first [xxx] frames of a network trace using Wireshark tools, follow these steps:

1. **Determine the Number of Packets**: Use `capinfos` to find out how many packets are in the corrupted file.
   ```bash
   C:\Program Files\Wireshark> capinfos C:\Downloads\mycap.bad.pcap
   <removed>
   Number of interfaces in file: 1
   Interface #0 info:
                        Encapsulation = Ethernet (1 - ether)
                        Capture length = 256
                        Time precision = microseconds (6)
                        Time ticks per second = 1000000
                        Number of stat entries = 0
                        Number of packets = 41579
   ```
   This command provides details about the capture file, including the total number of packets 41579.
2. **Extract the First 41579 Frames**: Use `editcap` to cut the trace down to the first 41579 frames, assuming these are problem-free.
   ```bash
   C:\Program Files\Wireshark> editcap -r C:\Downloads\mycap.bad.pcap C:\Downloads\mycap.fix.pcap 1-41579
   ```
3. **Verify the Output**: Open the file `mycap.fix.pcap` in Wireshark to ensure there are no error messages.

This process helps you create a clean capture file for analysis.

## Sample 13 - Handle duplicate logged packets in tcpdump , for example NVA or multi-layer capture. 

-d  Attempts to remove duplicate packets. 
-I  Ignore the specified number of bytes at the beginning of the frame during MD5 hash calculation

   ```
   C:\Program Files\Wireshark\editcap -d test.pcap test_dedup.pcap

   # Ignore first 26 bytes and start dedup
   C:\Program Files\Wireshark\editcap -d -I 26 test.pcap test_dedup.pcap
   ```

## Sample 14 - To address the issue of handling device capture with time shifts for a single TCP stream.

**Problem Statement:**
When performing infrastructure captures using methods like port mirroring or ERSPAN, the network traces collected from multiple locations may have time stamps that are misaligned across the different trace files. This misalignment creates challenges for tools like Wireshark, which struggle to accurately analyze retransmissions and duplicate acknowledgments due to the inconsistent timing. As a result, it becomes difficult to obtain a coherent view of the network activity.

**Proposed Solution:**
To achieve better alignment and analysis of the captured network traces, the idea is to reorder the packets based on a combination of sequence numbers and acknowledgment numbers. By focusing on these TCP attributes, you can realign the packets in a way that provides a clearer packet-to-packet view, independent of the time stamps. This method can improve the accuracy of analyzing retransmissions and duplicate acknowledgments, leading to a more comprehensive understanding of the network activity.

It is important to note that this proposal is only applicable to a single TCP stream and requires further testing to determine its reliability for other scenarios.


```kql

| where flowhash == '-111319814355929876'  // required to limited to one flow hash. 
| extend seq=tolong(tcpseq) + tolong(tcpack)
| extend cal_ack=tolong(tcpseq)+tolong(tcplen)
| order by seq asc
| project-reorder flowhash, seq, SourceCA, DestCA, ipidinner, tcpsrcport, tcpdstport, tcpseq, tcpack,cal_ack, Length,  Info
| extend delta = todatetime(TT) - prev(todatetime(TT))
```

## Sample 15 - Good sample of tcpdump with rolling capture and clean up

Shell script that captures network traffic on all network interfaces except the loopback interface (`lo`) using `tcpdump` and each interface save to different file and send to background service
```
for iface in $(ls /sys/class/net | grep -v lo); do nohup tcpdump -i "$iface" -s 128 -C 200 -W 1000 -w "/path/tcpdump_$(hostname)_${iface}_$(date -u +%Y%m%d_%H%M%S.%3N).pcap" &
```

killall tcpdump (Run as root user)
```
# ps -ef | grep tcpdump | grep tcpdump_ | grep .pcap | grep -v grep | awk '{print "kill -9 "$2}' | sh
or
# ps -ef | grep tcpdump_ | grep .pcap | grep -v grep | awk '{print $2}' | xargs kill -15
or
# ps -ef | grep tcpdump_ | grep .pcap | grep -v grep | awk '{print $2}' | xargs kill -9
```
