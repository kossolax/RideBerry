#!/bin/bash

apn=$1
wwan=$2

# check if we are root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi
# check if env vars are set
if [ -z "$wwan" ]; then
  echo "wwan is not set"
  exit 1
fi
if [ -z "$apn" ]; then
  echo "apn is not set"
  exit 1
fi
if [ ! -f "/usr/sbin/simcom-cm" ]; then
  echo "simcom-cm is not installed"
  exit 1
fi
if [ ! -f "/usr/bin/screen" ]; then
  echo "screen is not installed"
  exit 1
fi


is_interface_valid() {
  if ip addr show $wwan 2>/dev/null | grep -qe "state UP" -e "inet " ; then
    return 0
  fi
  return 1
}
is_screen_valid() {
  if /usr/bin/screen -list | grep -q $wwan; then
    return 0
  fi
  return 1
}
start() {
  echo -n "starting..."

  while true; do
    /usr/bin/screen -L -Logfile $pipe -dmS $wwan /usr/sbin/simcom-cm -s $apn -i $wwan
    sleep 1

    for ((i=0; i<60; i++)); do

      if ! is_screen_valid; then
        echo "Screen session is not valid, retrying..."
        break 1 # break the inner loop
      fi

      if is_interface_valid; then
        echo "Interface is up and running."
        break 2 # break the outer loop
      fi

      sleep 1
    done
    
    echo "Connection failed, retrying..."
    /usr/bin/screen -S $wwan -X quit
    ifconfig $wwan down
  done

  sleep 1
  echo "complete"
}
stop() {
  echo -n "stopping..."

  /usr/bin/screen -S $wwan -X quit
  ifconfig $wwan down
  sleep 1
  
  echo "complete"
}
restart() {
  stop
  start
}
config() {
  echo "setup DNS"
  echo "nameserver 1.1.1.1" > /etc/resolv.conf
  echo "nameserver 8.8.8.8" >> /etc/resolv.conf
}



last_log=""
pipe="/tmp/screen_$wwan.pipe"
rm -f $pipe 2>/dev/null
touch $pipe
if is_screen_valid; then
  /usr/bin/screen -S $wwan -X hardcopy $pipe
else
  start
fi

(
  while true; do

    log=$(tail -n 5 $pipe | grep "\S" | tail -n 1)
    if [ "$last_log" != "$log" ]; then
      last_log=$log
      echo $last_log
    fi

    # Restart the connection if the screen session is not active
    if ! is_screen_valid; then
      echo "No active screen session found for $wwan. Restarting..."
      start
    fi

    # Restart the connection if the interface is down
    if ! is_interface_valid; then
      echo "Interface $wwan is down. Restarting..."
      restart
    fi

    # Restart the connection if the log indicates it was lost
    if [[ "$last_log" == *"DataCap: UNKNOW"* ]]; then
      echo "Connection lost. Restarting..."
      restart
    fi

    sleep 1
  done
) &

echo "Monitoring started for $wwan..."