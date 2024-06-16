#!/bin/bash

keypath="/root/gt.key"

# check if we are root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# check if glorytun is installed
if [ ! -f "/usr/sbin/glorytun" ]; then
    echo "glorytun is not installed, attempt to install it"
    wget https://github.com/angt/glorytun/releases/download/v0.3.4/glorytun-0.3.4-$(arch)-linux-musl.bin -O /usr/sbin/glorytun
    chmod +x /usr/sbin/glorytun
fi

# check if we have a keyfile
if [ ! -f "$keypath" ]; then
    echo "keyfile not found! import it from server and place it at $keypath"
	exit 1
fi

echo "setup DNS"
if [ -x /sbin/resolvconf ]; then
    echo "nameserver 1.1.1.1" | resolvconf -a "tun0.bonding"
    echo "nameserver 8.8.8.8" | resolvconf -a "tun0.bonding"
else
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

echo "getting connexion info"
#server=$(dig +short vps.zaretti.be | tail -n 1)
server="54.37.50.166"
wlan=$(ip addr show wlan0 | awk '/inet / {print $2}' | xargs ipcalc -n | awk '/Network:/ {print $2}')

client0=$(ifconfig wwan0 | awk '/inet / {print $2}')
network0=$(ip addr show wwan0 | awk '/inet / {print $2}' | xargs ipcalc -n | awk '/Network:/ {print $2}')
gateway0=$(ip route show dev wwan0 | awk '/default via/ {print $3}')

client1=$(ifconfig wwan1 | awk '/inet / {print $2}')
network1=$(ip addr show wwan1 | awk '/inet / {print $2}' | xargs ipcalc -n | awk '/Network:/ {print $2}')
gateway1=$(ip route show dev wwan1 | awk '/default via/ {print $3}')

echo "starting vpn to $server"
glorytun bind 0.0.0.0 to $server keyfile $keypath &
sleep 3

echo "adding $client to bound"
ifconfig tun0 10.0.1.2 pointopoint 10.0.1.1 up
#glorytun path up $client0 rate tx 10mbit rx 10mbit
#glorytun path up $client1 rate tx 10mbit rx 10mbit

echo "changing route"

echo "1" > /proc/sys/net/ipv4/ip_forward
# if ! grep -q wwan0 /etc/iproute2/rt_tables; then
# 	echo "100	wwan0" >> /etc/iproute2/rt_tables
# fi
# if ! grep -q wwan1 /etc/iproute2/rt_tables; then
# 	echo "200	wwan1" >> /etc/iproute2/rt_tables
# fi

# ip route add $network0 dev wwan0 src $client0 table 100
# ip route add default via $gateway0 table 100

# ip route add $network1 dev wwan1 src $client1 table 200
# ip route add default via $gateway1 table 200

#ip route del default dev wwan0
#ip route del default dev wwan1
ip route add default via 10.0.1.2 dev tun0

echo "add from into table"
# ip rule add from $client0 table 100
# ip rule add from $client1 table 200

echo "routing wifi to table 100 $wlan and $network1"
#ip route add $wlan dev wlan0 table 100
#ip route add $network1 dev wwan1 table 100
#ip route add 127.0.0.0/8 dev lo table 100

echo "routing wifi to table 200 $wlan and $network0"
#ip route add $wlan dev wlan0 table 200
#ip route add $network0 dev wwan0 table 200
#ip route add 127.0.0.0/8 dev lo table 200

echo "ready"
sleep inf
