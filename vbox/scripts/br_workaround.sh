#!/bin/bash 
eth1_mac=`ip link show dev eth1 | grep -oP '(?<=link/ether\s)(.*)(?=\sbrd\s)'`
eth1_bridge=`ip link show dev eth1 | grep -oP '(?<=master\s)(.*)(?=\sstate)'`
eth1_bridge_mac=`ip link show dev ${eth1_bridge} | grep -oP '(?<=link/ether\s)(.*)(?=\sbrd\s)'`

eth2_mac=`ip link show dev eth2 | grep -oP '(?<=link/ether\s)(.*)(?=\sbrd\s)'`
eth2_bridge=`ip link show dev eth2 | grep -oP '(?<=master\s)(.*)(?=\sstate)'`
eth2_bridge_mac=`ip link show dev ${eth2_bridge} | grep -oP '(?<=link/ether\s)(.*)(?=\sbrd\s)'`

if [ ! -z "${eth1_bridge}" ]; then 
   ip link set ${eth1_bridge} address ${eth1_mac}
   #ip link set eth1 address ${eth1_bridge_mac}
fi

if [ ! -z "${eth2_bridge}" ]; then 
   ip link set ${eth2_bridge} address ${eth2_mac}
   #ip link set eth2 address ${eth2_bridge_mac}
fi
