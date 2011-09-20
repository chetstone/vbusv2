# Dynamic Dns updater for DL2 busybox.
# This script is adapted from the script at
# http://brionews.com/cont/c_dynamic-ip-update-shell-script.php
#
# This is for no-ip.com dynamic dns service. To adapt it for dyndns.com
# see the above site.
# Note that the first wget uses dyndns to discover our ip because according
# to the above site they couldn't get no-ip's server to work.
#
# Settings
#set -ve
. /root/config
#
# argument -f force_id
case "$1" in
        -f)  forceip="$2";; # for testing
        -h)  echo "USAGE: $0 [-f force_ip]";
            exit 2;;
    esac


if [ -z $forceip ]
then
  wget http://checkip.dyndns.org:8245/ -O - | grep Current | awk '{print $6}' |sed 's/<.*//' > ip_noip-new.txt
else
  echo ${forceip} > ip_noip-new.txt
fi
#

ip=$(cat ip_noip-new.txt)
# for testing
#
date >> ip_noip-date.txt
#
 if [ -f ip_noip-old.txt ]
 then
    cat ip_noip-old.txt >> ip_noip-history.txt
 else
    echo 'reboot' > ip_noip-old.txt
 fi  
# only update if address has changed (or on reboot)
if ! diff ip_noip-new.txt ip_noip-old.txt
   then
   wget "http://${user}:${pass}@dynupdate.no-ip.com/nic/update?hostname=${host}&myip=${ip}" -O -
fi
#
cp ip_noip-new.txt ip_noip-old.txt
