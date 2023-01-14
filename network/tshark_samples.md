# Using Tshark to dump Packet details into TEXT format

Everyday while I am working with Network trace, there are many scenerios
- Share the trace analyze details with colleage, use screenshot (PrtScr or FastStone capture) is one way, but not very friend for email or MarkDown edit. 
- Work with super large PCAP file to get useful insight, but filter in Wireshark is very slow
- Work with many(1000+) PCAP files to apply same filter to get useful insight, combine pcap into one file could help but will hit the second limitation above. 

Today, I introduce some ideas to leverage tshark work with PCAP file(s). 

## Sample One - Expand TCP Details of one specific Frame
```
C:\Program Files\Wireshark>tshark -r d:\temp\mytrace.pcapng -V -O tcp frame.number == 5
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

## Sample Two - list conversation view by ip 
```
C:\Program Files\Wireshark>tshark -r d:\temp\mytrace.pcapng -qzconv,ip
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

## Sample Three - list conversation view by tcp
```
C:\Program Files\Wireshark>tshark -r d:\temp\mytrace.pcapng -qzconv,tcp
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

## Sample Four - dump PCAP to CSV , use ADX (Kusto) to analyze trace in fast fashion
For big trace analyze, export trace to CSV then import ADX for fast analyze is nature way to speed-up analyze. Using Tshark we can "convert" pcap to csv, here is my favorite fields commonly used when analyze TCP/UDP network trace. 

TSHARK covert to csv , Fields selected
``` cmd 
"c:\program files\wireshark\tshark" -r my.pcapng -T fields -e frame.number -e frame.time_epoch -e frame.time_delta_displayed -e ip.src -e ip.dst -e ip.id -e ip.proto -e tcp.seq -e tcp.ack -e frame.len -e tcp.srcport -e tcp.dstport -e udp.srcport -e udp.dstport -e tcp.analysis.ack_rtt -e frame.protocols -e _ws.col.Info -e eth.src -e eth.dst -E header=y -E separator=, -E quote=d > my.pcapng.csv
```

ADX (Kusto) create table and import from CSV,
``` kql
.drop table trace

.create table trace (framenumber:long,frametime:string,DeltaDisplayed:string,Source:string,Destination:string,ipid:string,Protocol:int,tcpseq:string,tcpack:string,Length:int,tcpsrcport:int,tcpdstport:int,udpsrcport:int,udpdstport:int,tcpackrtt:string,frameprotocol:string,Info:string,ethsrc:string,ethdst:string)

.ingest into table trace (@"c:\temp\my.pcapng.csv") with (format='csv',ignoreFirstRecord=true)
```

Sample query and covert Epoch time to UTC readable format 
``` kql
//convert epoch time to UTC display time with Seconds
trace 
| extend aa=tolong(replace_string(frametime,'.',''))/1000
| extend TT=unixtime_microseconds_todatetime(aa)
| project framenumber,TT,DeltaDisplayed, Source, Destination, ipid, Protocol,tcpseq, tcpack, Length, Info, tcpsrcport, tcpdstport, udpdstport, udpsrcport,ethsrc, ethdst, frameprotocol
| take 20

framenumber	TT	DeltaDisplayed	Source	Destination	ipid	Protocol	tcpseq	tcpack	Length	Info	tcpsrcport	tcpdstport	udpdstport	udpsrcport	ethsrc	ethdst	frameprotocol
1	2022-11-04 06:13:53.6285160	0.000000000	10.115.68.111	122.111.111.111	0xb3f6	6	3443987890	0	66	54010 → 443 [SYN] Seq=3443987890 Win=64240 Len=0 MSS=1460 WS=256 SACK_PERM	54010	443			c0:fb:f9:c6:dc:bc	68:3a:1e:74:ee:a0	eth:ethertype:ip:tcp
2	2022-11-04 06:13:53.6692370	0.040721000	122.111.111.111	10.115.68.111	0x0000	6	3280391636	3443987891	66	443 → 54010 [SYN, ACK] Seq=3280391636 Ack=3443987891 Win=64240 Len=0 MSS=1360 SACK_PERM WS=1024	443	54010			68:3a:1e:74:ee:a0	c0:fb:f9:c6:dc:bc	eth:ethertype:ip:tcp
3	2022-11-04 06:13:53.6694950	0.000258000	10.115.68.111	122.111.111.111	0xb3f7	6	3443987891	3280391637	54	54010 → 443 [ACK] Seq=3443987891 Ack=3280391637 Win=131840 Len=0	54010	443			c0:fb:f9:c6:dc:bc	68:3a:1e:74:ee:a0	eth:ethertype:ip:tcp
4	2022-11-04 06:13:53.6805270	0.011032000	10.115.68.111	122.111.111.111	0xb3f8	6	3443987891	3280391637	571	Client Hello	54010	443			c0:fb:f9:c6:dc:bc	68:3a:1e:74:ee:a0	eth:ethertype:ip:tcp:tls
5	2022-11-04 06:13:53.7203860	0.039859000	122.111.111.111	10.115.68.111	0x71f7	6	3280391637	3443988408	62	443 → 54010 [ACK] Seq=3280391637 Ack=3443988408 Win=64512 Len=0	443	54010			68:3a:1e:74:ee:a0	c0:fb:f9:c6:dc:bc	eth:ethertype:ip:tcp
6	2022-11-04 06:13:53.7224630	0.002077000	122.111.111.111	10.115.68.111	0x71f8	6	3280391637	3443988408	1384	Server Hello	443	54010			68:3a:1e:74:ee:a0	c0:fb:f9:c6:dc:bc	eth:ethertype:ip:tcp:tls

```


### Tips
While work with a lot of pcap files, let's create one batch file 

```cmd
* following command must run Windows Command Prompt not Powershell
for /f "delims=" %a in ('dir /b /o *.cap') do "c:\program files\wireshark\tshark" -r "%a" -T fields -e frame.number -e frame.time_epoch -e frame.time_delta_displayed -e ip.src -e ip.dst -e ip.id -e ip.proto -e tcp.seq -e tcp.ack -e frame.len -e tcp.srcport -e tcp.dstport -e udp.srcport -e udp.dstport -e tcp.analysis.ack_rtt -e frame.protocols -e _ws.col.Info -e eth.src -e eth.dst -E header=y -E separator=, -E quote=d > "%a.csv"

before process
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

After process
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

## Sample Five - detect 1s delay TCP SYN - TCP SYN/ACK for port 6379 traffic from 1000+ trace file 
Today I get into a situation that need to look into 1000+ pcap files to detect a problem whether TCP 3-way handshake is longer than 1 second

To detect TCP 3-way handshake is longer than 1 second, let's use Wireshark filter
```
tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1
```

To make the detection works for 1000+ files, let's use Windows Batch file
```cmd
for /f "delims=" %a in ('dir /b /o d:\tracefile\*.pcap') do "c:\program files\wireshark\tshark" -r "d:\tracefile\%a" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"
```

Result is promising....
```cmd
C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_43_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_44_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"
22808 2023-01-13 16:44:47.160183 0.000000 10.227.8.192 → 10.227.6.87  0x0000 (0),0x0100 (256),0x0000 (0) TCP 2945986252 1537613497 1.035904000 154 6379 → 41990 [SYN, ACK] Seq=2945986252 Ack=1537613497 Win=43440 Len=0 MSS=1418 SACK_PERM TSval=2115729317 TSecr=842724217 WS=512
22810 2023-01-13 16:44:47.160438 0.000255 10.227.4.160 → 10.227.6.87  0x0000 (0),0x0100 (256),0x0000 (0) TCP 1741601663 3024541421 1.036066000 154 6379 → 38444 [SYN, ACK] Seq=1741601663 Ack=3024541421 Win=43440 Len=0 MSS=1418 SACK_PERM TSval=3755097511 TSecr=3102397576 WS=512

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_45_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_46_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"

C:\Windows\System32>"c:\program files\wireshark\tshark" -r "c:\tracefile\file_16_47_00.pcap" "tcp.analysis.ack_rtt >1 and tcp.flags.syn == 1 and tcp.flags.ack ==1 and tcp.srcport == 6379"
```

We can conclude  in c:\tracefile\file_16_44_00.pcap,  there are two streams, let's find the exact PCAP file and check further in Wirehsark. 
```cmd
10.227.8.192 → 10.227.6.87   6379 → 41990 [SYN, ACK] is taking 1.03590400 to response
10.227.4.160 → 10.227.6.87   6379 → 38444 [SYN, ACK] is taking 1.03606600 to response 
```




