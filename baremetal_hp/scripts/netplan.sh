#!/bin/bash
mkdir -p /etc/network/interfaces.d
unset addr
addr+=(`ip addr | grep -oP '(?<=inet\s)(.*)(?=\sbrd\s)' | awk '{print $1}' | sort -u`)
gw=`ip route | grep -oP '(?<=default\svia\s)(.*)(?=\sdev\s)'`

cat << EOF > /etc/network/interfaces.d/eth0
auto eth0
iface eth0 inet static
address `ipcalc ${addr[0]} | awk '/Address:/{print $2}'`
netmask `ipcalc ${addr[0]} | awk '/Netmask:/{print $2}'`
gateway ${gw}
EOF

cat << EOF > /etc/network/interfaces.d/eth1
auto eth1
iface eth1 inet static
address `ipcalc ${addr[1]} | awk '/Address:/{print $2}'`
netmask `ipcalc ${addr[1]} | awk '/Netmask:/{print $2}'`
EOF

cat << EOF > /etc/network/interfaces.d/eth2
auto eth2
iface eth2 inet static
address `ipcalc ${addr[2]} | awk '/Address:/{print $2}'`
netmask `ipcalc ${addr[2]} | awk '/Netmask:/{print $2}'`
EOF

sed  -i 's|GRUB_CMDLINE_LINUX=""|GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"|g' /etc/default/grub  

ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf
sed -i 's/#DNS=/DNS=1.1.1.1 8.8.8.8/' /etc/systemd/resolved.conf
service systemd-resolved restart

grub-mkconfig -o /boot/grub/grub.cfg
apt-get --assume-yes purge nplan netplan.i
systemctl unmask networking
systemctl enable networking


cat << EOF > /etc/hosts
127.0.0.1 localhost ${HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

# Clear partitions:
dd if=/dev/zero of=/dev/sdb1 bs=4000 count=10
dd if=/dev/zero of=/dev/sdb2 bs=4000 count=10

