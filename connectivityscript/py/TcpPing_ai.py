#!/usr/bin/env python3

"""
Author: Otto Deng

TCPPing Test, Post result to Azure Application Insight. 
Usage: ./tcpping.py host [port]
- Ctrl-C Exits with Results

Steps:
1. change appinsights-connection-string to your own AI connection string
2. sudo apt install python3-pip -y
3. pip install opencensus-ext-azure
4. nohup python3 tcpping2appinsight.py api.twitter.com 443 > api.twitter.com 2>&1 &

"""

import logging
import sys
import socket
import time
import signal
from timeit import default_timer as timer
from opencensus.ext.azure.log_exporter import AzureLogHandler

logger = logging.getLogger(__name__)
logger.addHandler(AzureLogHandler(connection_string=<appinsights-connection-string>))

# Alternatively manually pass in the connection_string
# logger.addHandler(AzureLogHandler(connection_string=<appinsights-connection-string>))

"""Generate random log data."""
logger.setLevel(logging.INFO)
# logger.info('Hello, World!2')

# Default Settings
# Default to 55000 connections max
# Src Port will follow the count num, start with 10000
host = None
port = 80
maxCount = 65000
count = 10000

## Inputs

# Required Host
try:
    host = sys.argv[1]
except IndexError:
    print("\u001b[1m\u001b[37mUsage: \u001b[32mtcpping.py \u001b[37m[\u001b[32mip\u001b[37m] \u001b[37m[\u001b[32mport\u001b[37m] \u001b[37m[\u001b[32mmaxCount\u001b[37m]")
    sys.exit(1)

# Optional Port
try:
    port = int(sys.argv[2])
except ValueError:
    print("Error: Port Must be Integer.", sys.argv[3])
    sys.exit(1)
except IndexError:
    pass

# Optional maxCount
try:
    maxCount = int(sys.argv[3])
    if maxCount > 65000:
        print("Error: Max Count Value Must be Less than 65000, Your input is:", sys.argv[3])
        sys.exit(1)
except ValueError:
    print("Error: Max Count Value Must be Integer", sys.argv[3])
    sys.exit(1)
except IndexError:
    pass

def signal_handler(signal, frame):
    """ Catch Ctrl-C and Exit """
    sys.exit(0)

# Register SIGINT Handler
signal.signal(signal.SIGINT, signal_handler)

# Loop while less than max count or until Ctrl-C caught
while count < maxCount:

    # Increment Counter
    count += 1

    success = False

    # New Socket
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # 1sec Timeout
    s.settimeout(1)

    # Start a timer
    s_start = timer()

    # Try to resolve DNS
    try:
        host = sys.argv[1]
        hostip = socket.gethostbyname(host)
        # print("host: ", host, "hostip: ", hostip)
        # ends['dns'] = datetime.datetime.now()
        # print("DNS Lookup: %s" % (ends['dns'] - starts['dns']))
        dns_stop = timer()
        dns_runtime = "%.2f" % (1000 * (dns_stop - s_start))
    except socket.gaierror:
        # print("Error: Hostname could not be resolved. Hostname: ",host)
        properties = {'custom_dimensions': {
            'Message': 'Hostname could not be resolved', 
            'Hostname': host
            }}
        logger.warning('DNS Resolver Failed', extra=properties)
        time.sleep(1)
        continue


    # Try to Connect
    try:
        s.bind(('', count))
        s.connect((host, int(port)))
        srcip, srcport = s.getsockname()
        dstip, dstport = s.getpeername()
        # print("srcip: ", srcip, "srcport: ", srcport)
        # print("dstip: ", dstip, "dstport: ", dstport)
        # s.shutdown(socket.SHUT_RD)
        success = True
    
    # Connection Timed Out
    except socket.timeout:
        #print("Connection socket timedout",host, hostip)
        properties = {'custom_dimensions': {
            'Message': 'TCP Connection timeout', 
            'Hostname': host,
            'DstIP': hostip,
            'DstPort': port,
            'SrcPort': count
            }}
        logger.warning('TCP Connection timeout', extra=properties)        
        #failed += 1
    except OSError as e:
        print("OS Error:", e)
        # print("Connection OS Error", host, dstip, port, srcip, srcport, s_runtime)
        #failed += 1


    # Stop Timer
    s_stop = timer()
    s_runtime = "%.2f" % (1000 * (s_stop - dns_stop))

    if success:
        # print("hostname=%s dstip=%s dstport=%s srcip=%s srcport=%s dns_latency=%s ms tcp_latency=%s ms " % (host, dstip, port, srcip, srcport, dns_runtime, s_runtime))
        properties = {'custom_dimensions': {
            'Message': 'Success', 
            'Hostname': host,
            'DstIP': hostip,
            'DstPort': port,
            'SrcIP': srcip,
            'SrcPort': count,
            'DNS_Latency': dns_runtime,
            'TCP_Latency': s_runtime
            }}
        logger.info('Success', extra=properties)      

    # Sleep for 1sec
    if count < maxCount:
        time.sleep(1)
    elif count >= maxCount:
        count = 10000
