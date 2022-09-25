############################################################################
#Author: Alvin Lou,     

#Usage: ./Test_tcpping.sh -d bingtest.com -p 443
#Output: build a TEXT output Warp on top of TCPPING, it will record the timestamp and failures into local file.
#Options:

#Dependencies:  
#tcpping & tcptraceroute

#Limitations: Will need Internet access for the first run.

#Change history:
#v1.0, basic function works on Redhat, CentOS and Ubuntu.
#v1.1, adding verify ip address and FQDN.
############################################################################

#!/bin/bash
#DEFLOGPATH="/var/tmp/"
VER="v1.0"

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts d:p:r:v option
do
case "${option}"
in
d) DEST=${OPTARG};;
p) PORT=${OPTARG};;
#l) LOGPATH=${OPTARG};;
r) REPEAT=${OPTARG};;
v) VER=${OPTARG};;
?) usage; exit ;;
esac
done

DISTRO=`cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g' | awk '{print $1}'`
echo "Your are running on Linux Distro $DISTRO"

if [[ $DISTRO =~ "Ubuntu" ]]; then
#sudo wget -N http://www.vdberg.org/~richard/tcpping
#sudo chmod 755 tcpping
    FILEDEP="/usr/bin/tcptraceroute"
    if [ -e "$FILEDEP" ]; then
        echo "tcptraceroute exists"
    else
        echo "tcptraceroute does not exist, downloading new file of tcpping"
        sudo apt install tcptraceroute -y
        #sudo chmod 755 tcptraceroute
    fi
elif [[ $DISTRO =~ "CentOS" ]]; then
    echo "CentOS has buildin tcptraceroute"
elif [[ $DISTRO =~ "Red" ]]; then  
    echo "RedHat has buildin tcptraceroute"
else 
    echo "unknow os: $DISTRO"
    exit 1
fi

echo "Download tcpping to default /usr/bin"
cd /usr/bin
URL="http://www.vdberg.org/~richard/tcpping"
FILE="/usr/bin/tcpping"
if [ -e "$FILE" ]; then
    echo "tcpping exists"
else
    echo "tcping does not exist, downloading new file of tcpping"
    sudo wget -N $URL 
    sudo chmod 755 tcpping
fi

timeStart=`date "+%Y-%m-%d-%H:%M:%S"`
testStart=$(date +%s)
echo -e "Create log file at $timeStart"
LOGFILE=/var/tmp/`/bin/hostname`_$timeStart.tcpout
touch "$LOGFILE"
echo -e "Created $LOGFILE successfully"

#Capture ctrl+c
trap ctrl_c INT

function ctrl_c() {
    echo "*** Trapped CTRL-C"
}

echo -e "Run tcpping command to test $DEST with PORT $PORT"
if [ ! -z $REPEAT ]; then
    command="sudo tcpping -d -r $REPEAT $DEST $PORT 2>&1 | tee -a $LOGFILE"
else
    command="sudo tcpping -d $DEST $PORT 2>&1 | tee -a $LOGFILE"
fi
eval $command

testEnd=$(date +%s)
timeDiff=$(($testEnd - $testStart))
echo -e "SUMMARY: Elapsed $timeDiff seconds"
succeed="successfully tcpping `grep -ni 'tcp response from' $LOGFILE| wc -l`"
echo $succeed 2>&1 | tee -a $LOGFILE
#failure="failed tcpping `grep -ni 'no response (timeout)' $LOGFILE| wc -l`"
failure="failed tcpping `grep -E '^$|"no response"' $LOGFILE| wc -l`"
echo $failure 2>&1 | tee -a $LOGFILE

#END
