#!/bin/bash
brctl addif br1 veth3
brctl addif br0 veth1
ifconfig br0 up
ifconfig br1 up
