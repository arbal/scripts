#!/bin/bash
#
# poweron_run.sh 
#
# Power on script i.e. when tesla wakes up the hub is powered so our PI 
# should be booting. This script make use of this to do anthying we want
# to do when PI is powered on
#
# Note: copy this script to /root/scripts or other place refered in crontab path
#
# Author:  Arul Selvan
# Version: Jul 4, 202

# google dns for validating connectivity
gdns=8.8.8.8
my_name=`basename $0`
log_file="/var/log/$(echo $my_name|cut -d. -f1).log"
home_public_ip=`dig +short selvans.net @$gdns`
# should take this also as env option later.
ifttt_event_name="pizero"
ifttt_api="https://maker.ifttt.com/trigger/$ifttt_event_name/with/key"
ssh_port=22

#  ---------- main ---------------
echo "[INFO] `date`: $my_name starting..." >> $log_file

# check if we need to punch hole for ssh access from external hosts
# assumes ufw is setup already and activated.
if [ ! -z "${EXTERNAL_IP_LIST}" ] ; then
  echo "[INFO] checking and/or enabling external hosts for ssh access" >> $log_file
  if [ -z "${EXTERNAL_SSH_PORT}" ]; then
    echo "[WARN] using $ssh_port for ssh port, highly recomended to use a different port!" >> $log_file
  else
    ssh_port=${EXTERNAL_SSH_PORT}
    echo "[INFO] using $ssh_port for ssh port!" >> $log_file
  fi
  # go through the list
  external_ip_list=${EXTERNAL_IP_LIST}
  for external_ip in $external_ip_list ; do
    echo "[INFO] checking and/or adding $external_ip" >> $log_file
    ufw status |grep $external_ip >> $log_file 2>&1
    if [ $? -eq 0 ] ; then
      echo "[INFO] the external IP ($external_ip) already in firewall allowed list" >> $log_file
      continue
    else
      echo "[INFO] adding external IP ($external_ip) to firewall allowed list" >> $log_file
      ufw allow from $external_ip to any port $ssh_port >> $log_file 2>&1
      ufw status |grep $external_ip >> $log_file 2>&1
    fi
  done
else
  echo "[WARN] no EXTERNAL_IP_LIST env variable set, skiping firewall access setup." >> $log_file
fi

# first check if we got connectivity.
/bin/ping -t30 -c3 -q $gdns >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  echo "[WARN] We dont have connectivity. force dhcpd? or force wpa_supplicant to try again?" >> $log_file
  # for now, exit; will figureout how to force wlan to reconnect.
  exit
fi

# check if we have IFTTT creds are provided via env variable
if [ -z "${IFTTT_KEY}" ] ; then
  echo "[ERROR] no IFTTT_KEY no message is sent via IFTTT!" >> $log_file
  exit
fi

# find pi's egress IP
my_ip=`dig -p443 +short myip.opendns.com @resolver1.opendns.com`
pi_hostname=`hostname`
timestamp=`date`

# post a message to the IFTTT
echo "[INFO] sending message via IFTTT!" >> $log_file
ifttt_endpoint="$ifttt_api/$IFTTT_KEY"
curl -w "\n" -s -X POST \
  -F "value1=$pi_hostname's public IP is '$my_ip'" \
  -F "value2=$pi_hostname is/was powered on at $timestamp" \
  $ifttt_endpoint >> $log_file 2>&1


echo "[INFO] nothing more for now, exiting" >> $log_file

# TODO: more stuff later ...

