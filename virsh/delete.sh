#!/bin/bash
QEMU_DISK_PARTITION="/dev/nvme0n1p2"
DISK_DIR="/opt/qemu_disks"
DISK_IMAGE="ubuntu-20.04.6-live-server-amd64.iso"
VM_LIST=("srv01" "srv02" "srv03")
MEM_LIST=("8192000" "8192000" "4096000")
CPU_LIST=("4" "4" "4")
VNC_PORT=("5001" "5002" "5003")
PODMAN_IMAGE_NAME="ubuntu-auto-install"
PODMAN_IMAGE_VERSION="0.0.1"
PODMAN_NAME="build"
QEMU_USER="libvirt-qemu"
QEMU_GROUP="libvirt-qemu"




# Mount partition
sudo mkdir -p ${DISK_DIR}
sudo mount ${QEMU_DISK_PARTITION} ${DISK_DIR}
sudo chown -R ${USER}:${USER} ${DISK_DIR}
# Networks:
CWD=`pwd`
cd virsh_config
for n in `sudo virsh net-list | grep active | awk '{print $1}'`; do
   sudo virsh net-destroy ${n}
done

for n in `sudo virsh net-list --all | grep inactive | awk '{print $1}'`; do
   sudo virsh net-undefine ${n}
done


for n in `sudo virsh list | grep running | awk '{print $1}'`; do
   sudo virsh destroy ${n}
done

sudo rm -f ${DISK_DIR}/*.iso >/dev/null 2>&1&
sudo rm -f ${DISK_DIR}/*.img >/dev/null 2>&1&

sudo umount ${DISK_DIR}

