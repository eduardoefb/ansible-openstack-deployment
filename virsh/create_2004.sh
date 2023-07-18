#!/bin/bash
QEMU_DISK_PARTITION="/dev/nvme0n1p2"
DISK_DIR="/opt/qemu_disks"
# DISK_IMAGE="ubuntu-20.04.6-live-server-amd64.iso"
DISK_IMAGE="ubuntu-22.04.2-live-server-amd64.iso"
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

for f in net?.xml; do 
    sudo virsh net-define ${f}
done 

for n in `sudo virsh net-list --all | grep inactive | awk '{print $1}'`; do
   sudo virsh net-start ${n}
done

for n in `sudo virsh list | grep running | awk '{print $1}'`; do
   sudo virsh destroy ${n}
done

c=0
for i in ${VM_LIST[*]}; do
    export vm_name=${i}
    export mem=${MEM_LIST[i]}
    export cpus=${CPU_LIST[i]}
    export index=$((10+${c}))
    export vnc_port=$((${c}+5901))
    envsubst < vm.template > vm_${i}.xml
    c=$((${c}+1))
done

cd ${CWD}
# Pod for image creator:
podman stop build >/dev/null 2>&1

cat << EOF > Dockerfile
FROM ubuntu
RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3 cloud-init xorriso isolinux wget git curl gpg -y
EOF

if ! podman images | grep -P "${PODMAN_IMAGE_NAME}\s+${PODMAN_IMAGE_VERSION}"; then
    buildah bud -f Dockerfile -t ${PODMAN_IMAGE_NAME}:${PODMAN_IMAGE_VERSION}
fi 

rm Dockerfile

sudo rm -f ${DISK_DIR}/*.iso >/dev/null 2>&1&
sudo rm -f ${DISK_DIR}/*.img >/dev/null 2>&1&


podman stop ${PODMAN_NAME} >/dev/null 2>&1
podman run -t -d --name build --rm ${PODMAN_IMAGE_NAME}:${PODMAN_IMAGE_VERSION} bash
for i in ${VM_LIST[*]}; do
    podman cp ${DISK_IMAGE} ${PODMAN_NAME}:/root/ubuntu.iso
    podman cp auto_install_configs  ${PODMAN_NAME}:/root/
    podman cp ubuntu-autoinstall-generator.sh ${PODMAN_NAME}:/root/ubuntu-autoinstall-generator.sh
    podman exec -it ${PODMAN_NAME} /root/ubuntu-autoinstall-generator.sh -a -u /root/auto_install_configs/${i}.yml -s /root/ubuntu.iso -d /root/${i}.iso -c -k
    podman cp ${PODMAN_NAME}:/root/${i}.iso ${DISK_DIR}/     
done
podman stop ${PODMAN_NAME} >/dev/null 2>&1&


# Create disks:
for i in ${VM_LIST[*]}; do
    qemu-img create "${DISK_DIR}/${i}_disk_1.img" 80G -f raw
    qemu-img create "${DISK_DIR}/${i}_disk_2.img" 40G -f raw
    qemu-img create "${DISK_DIR}/${i}_disk_3.img" 40G -f raw
done

sudo chown -R ${QEMU_USER}:${QEMU_GROUP} ${DISK_DIR}

CWD=`pwd`
cd virsh_config
for f in vm*.xml; do
    sudo virsh create ${f}
done
cd ${CWD}
bash configure.sh
cd ../ansible
python3 create_inventory.py config.yml
time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml 

cd ${CWD}
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts get_rc_files.yml  

