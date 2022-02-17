#!/bin/bash
modprobe dummy

eth1=$(cat /sys/class/net/eth1/type)
if [[ $eth1 == 1 ]]
then
    echo "Interface eth1 already created"
else
    echo "Configuring eth1"
    ip link add eth1 type dummy
    ifconfig eth1 up
fi

eth2=$(cat /sys/class/net/eth2/type)
if [[ $eth2 == 1 ]]
then
    echo "Interface eth2 already created"
else
    echo "Configuring eth2"
    ip link add eth2 type dummy
    ifconfig eth2 up
fi