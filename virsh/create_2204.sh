#!/bin/bash
QEMU_DISK_PARTITION="/dev/nvme0n1p2"
DISK_DIR="/opt/qemu_disks"
#DISK_IMAGE="../iso/ubuntu-20.04.6-live-server-amd64.iso"
DISK_IMAGE="../iso/ubuntu-22.04.2-live-server-amd64.iso"
VM_LIST=("srv01" "srv02" "srv03")
MEM_LIST=("6144000" "4096000" "4096000")
CPU_LIST=("4" "4" "4")
VNC_PORT=("5001" "5002" "5003")
PODMAN_IMAGE_NAME="ubuntu-auto-install"
PODMAN_IMAGE_VERSION="0.0.2"
PODMAN_NAME="build"
QEMU_USER="libvirt-qemu"
QEMU_GROUP="libvirt-qemu"
AUTOINSTALL_CONFIG_DIR="config/autoinstall"
OPENSTACK_CONFIG_FILE="config/openstack/config.yml"
VIRSH_CONFIG_DIR="config/virsh"


set -x


# Mount partition
sudo mkdir -p ${DISK_DIR}
sudo mount ${QEMU_DISK_PARTITION} ${DISK_DIR}
sudo chown -R ${USER}:${USER} ${DISK_DIR}
# Networks:
CWD=`pwd`
cd ${VIRSH_CONFIG_DIR}
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
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3 cloud-init xorriso isolinux wget git curl gpg p7zip-full -y
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
    podman cp ${AUTOINSTALL_CONFIG_DIR}/${i}.yml ${PODMAN_NAME}:/root/user-data
    podman cp scripts/auto_2204.sh ${PODMAN_NAME}:/root/auto_2204.sh
    podman exec -it ${PODMAN_NAME} chmod +x /root/auto_2204.sh
    podman exec -it ${PODMAN_NAME} /root/auto_2204.sh
    podman cp ${PODMAN_NAME}:/root/ubuntu-autoinstall.iso ${DISK_DIR}/${i}.iso  
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
cd ${VIRSH_CONFIG_DIR}
for f in vm*.xml; do
    sudo virsh create ${f}
done
cd ${CWD}

# Remove servers from known_hosts
sed -i '/172.250.0.10/d' ${HOME}/.ssh/known_hosts
sed -i '/172.250.0.11/d' ${HOME}/.ssh/known_hosts
sed -i '/172.250.0.12/d' ${HOME}/.ssh/known_hosts

# create hosts file
cat << EOF > hosts 
[nodes]
172.250.0.10 ansible_user=cloud ansible_password=cloud
172.250.0.11 ansible_user=cloud ansible_password=cloud
172.250.0.12 ansible_user=cloud ansible_password=cloud

[controller]
172.250.0.10 ansible_user=cloud ansible_password=cloud

EOF

# Create config file
# To create the password:  echo -n "your_password" | openssl passwd -6 -stdin
cat << EOF > config.yml
nodes:
  - 172.250.0.10
  - 172.250.0.11
  - 172.250.0.12

key_file: ${HOME}/.ssh/id_rsa.pub
new_password: \$6\$u83aW56dcV7L6nYu\$KVqYYN6hv50j5aNIRpFEhMl.biaMhd/xPSQzByyAVgKqICP6DiqvIe7rIUL/DxdlkYNWV1GnXInqYM09cN7ja/

EOF

# Start configuration
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts configure.yml  --extra-vars "ansible_sudo_pass=cloud"

# Remove files:
rm -f config.yml
rm -f hosts

# Start openstack deployment:

cp ${OPENSTACK_CONFIG_FILE} ../ansible/
cd ../ansible
python3 create_inventory.py config.yml
time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml 

cd ${CWD}

cat << EOF > hosts 
[nodes]
172.250.0.10 ansible_user=cloud ansible_password=cloud
172.250.0.11 ansible_user=cloud ansible_password=cloud
172.250.0.12 ansible_user=cloud ansible_password=cloud

[controller]
172.250.0.10 ansible_user=cloud ansible_password=cloud

EOF

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts get_rc_files.yml  

set +x