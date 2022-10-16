# Using Tshark to dump Packet details into TEXT format

Everyday while I am working with Network trace, want to share the trace analyze details with colleage, use screenshot (PrtScr or FastStone capture) is one way, but not very friend for email or MarkDown edit. 

Today, i would like to introduce how to use tshark to dump the packet details as. 

## Sample One - Expand TCP Details only of one specific Frame

```
C:\Program Files\Wireshark>tshark -r d:\temp\mytrace.pcapng -V -O tcp frame.number == 2
Frame 2: 256 bytes on wire (2048 bits), 256 bytes captured (2048 bits) on interface unknown, id 0
Ethernet II, Src: Dell_ab:fa:a2 (d8:9e:f3:ab:fa:a2), Dst: Mellanox_cb:c9:ec (ec:0d:9a:cb:c9:ec)
Internet Protocol Version 4, Src: 25.86.198.43, Dst: 10.1.214.138
Generic Routing Encapsulation (ERSPAN)
Encapsulated Remote Switch Packet ANalysis Type I
Ethernet II, Src: AristaNe_6c:70:a8 (28:99:3a:6c:70:a8), Dst: AristaNe_a3:5e:75 (74:83:ef:a3:5e:75)
Internet Protocol Version 4, Src: 100.76.102.30, Dst: 10.67.88.91
Internet Protocol Version 4, Src: 52.168.28.222, Dst: 23.102.239.134
Transmission Control Protocol, Src Port: 4825, Dst Port: 16877, Seq: 2783611832, Ack: 2420665927, Len: 144
    Source Port: 4825
    Destination Port: 16877
    [Stream index: 1]
    [Conversation completeness: Incomplete (0)]
    [TCP Segment Len: 144]
    Sequence Number: 2783611832
    [Next Sequence Number: 2783611976]
    Acknowledgment Number: 2420665927
    0101 .... = Header Length: 20 bytes (5)
    Flags: 0x018 (PSH, ACK)
        000. .... .... = Reserved: Not set
        ...0 .... .... = Nonce: Not set
        .... 0... .... = Congestion Window Reduced (CWR): Not set
        .... .0.. .... = ECN-Echo: Not set
        .... ..0. .... = Urgent: Not set
        .... ...1 .... = Acknowledgment: Set
        .... .... 1... = Push: Set
        .... .... .0.. = Reset: Not set
        .... .... ..0. = Syn: Not set
        .... .... ...0 = Fin: Not set
        [TCP Flags: ·······AP···]
    Window: 1028
    [Calculated window size: 1028]
    [Window size scaling factor: -1 (unknown)]
    Checksum: 0x8de9 [unverified]
    [Checksum Status: Unverified]
    Urgent Pointer: 0
    [Timestamps]
        [Time since first frame in this TCP stream: 0.000000000 seconds]
        [Time since previous frame in this TCP stream: 0.000000000 seconds]
    [SEQ/ACK analysis]
        [Bytes in flight: 144]
        [Bytes sent since last PSH flag: 144]
    TCP payload (144 bytes)
    TCP segment data (144 bytes)
Transport Layer Security
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

