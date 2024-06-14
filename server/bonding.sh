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
    echo "keyfile not found, generating one"
    /usr/sbin/glorytun keygen > $keypath
fi

echo "starting server"
/usr/sbin/glorytun bind 0.0.0.0 keyfile $keypath &
while ! ifconfig tun0; do
  sleep 1
done

echo "enabling iface"
/usr/sbin/ifconfig tun0 10.0.1.1 pointopoint 10.0.1.2 up

echo "enabling nat"
iptables -w -t nat -A POSTROUTING -o ens3 -s 10.0.1.0/24 -j MASQUERADE
iptables -w -A FORWARD -s 10.0.1.0/24 -j ACCEPT
iptables -w -A FORWARD -d 10.0.1.0/24 -j ACCEPT

sleep inf