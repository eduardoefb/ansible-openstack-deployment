#!/bin/bash
export DISK_IMAGE="../iso/ubuntu-20.04.6-live-server-amd64.iso"
#export DISK_IMAGE="../iso/ubuntu-22.04.2-live-server-amd64.iso"
export SRV_LIST=("srv01" "srv02" "srv03")
export PODMAN_IMAGE_NAME="ubuntu-auto-install-bm"
export PODMAN_IMAGE_VERSION="0.0.4"
export PODMAN_NAME="buildbm"
export AUTOINSTALL_CONFIG_DIR="config/autoinstall"
export OPENSTACK_CONFIG_FILE="config/openstack/config.yml"
export ILO_SRV01='ssh -i ~/.ssh/id_dsa -o StrictHostKeyChecking=no -c aes256-cbc,aes192-cbc,aes128-cbc,3des-cbc -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oPubkeyAcceptedAlgorithms=+ssh-dss,ssh-rsa -oHostKeyAlgorithms=+ssh-dss,ssh-rsa eduabati@10.2.1.50'
export ILO_SRV02='ssh -i ~/.ssh/id_dsa -o StrictHostKeyChecking=no -c aes256-cbc,aes192-cbc,aes128-cbc,3des-cbc -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oPubkeyAcceptedAlgorithms=+ssh-dss,ssh-rsa -oHostKeyAlgorithms=+ssh-dss,ssh-rsa eduabati@10.2.1.51'
export ILO_SRV03='ssh -i ~/.ssh/id_dsa -o StrictHostKeyChecking=no -c aes256-cbc,aes192-cbc,aes128-cbc,3des-cbc -oKexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -oPubkeyAcceptedAlgorithms=+ssh-dss,ssh-rsa -oHostKeyAlgorithms=+ssh-dss,ssh-rsa eduabati@10.2.1.52'


set -x
CWD=`pwd`
cd ${CWD}

${ILO_SRV01} 'power off'
${ILO_SRV02} 'power off'
${ILO_SRV03} 'power off'

# Pod for image creator:
podman stop ${PODMAN_NAME} >/dev/null 2>&1

cat << EOF > Dockerfile
FROM ubuntu
RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3 apache2 cloud-init xorriso isolinux wget git curl gpg p7zip-full -y
EOF

if ! podman images | grep -P "${PODMAN_IMAGE_NAME}\s+${PODMAN_IMAGE_VERSION}"; then
    buildah bud -f Dockerfile -t ${PODMAN_IMAGE_NAME}:${PODMAN_IMAGE_VERSION}
fi 

rm Dockerfile

podman stop ${PODMAN_NAME} >/dev/null 2>&1
podman run -t -d -p 9000:80 --name ${PODMAN_NAME} --rm ${PODMAN_IMAGE_NAME}:${PODMAN_IMAGE_VERSION} bash
nohup podman exec -it ${PODMAN_NAME} apachectl -D FOREGROUND >/dev/null 2>&1&
podman cp ${DISK_IMAGE} ${PODMAN_NAME}:/root/ubuntu.iso
for i in ${SRV_LIST[*]}; do
    podman cp ${AUTOINSTALL_CONFIG_DIR}/${i}.yml ${PODMAN_NAME}:/root/user-data
    podman cp scripts/ubuntu-autoinstall-generator.sh ${PODMAN_NAME}:/root/ubuntu-autoinstall-generator.sh
    podman exec -it ${PODMAN_NAME} chmod +x /root/ubuntu-autoinstall-generator.sh
    podman exec -it ${PODMAN_NAME} /root/ubuntu-autoinstall-generator.sh -a -u /root/user-data -s /root/ubuntu.iso -d /var/www/html/${i}.iso -c -k         
done

# Configure boot:
${ILO_SRV01} 'vm cdrom insert http://10.2.1.32:9000/srv01.iso'
${ILO_SRV02} 'vm cdrom insert http://10.2.1.32:9000/srv02.iso'
${ILO_SRV03} 'vm cdrom insert http://10.2.1.32:9000/srv03.iso'

${ILO_SRV01} 'vm cdrom set boot_once'
${ILO_SRV02} 'vm cdrom set boot_once'
${ILO_SRV03} 'vm cdrom set boot_once'

${ILO_SRV01} 'vm cdrom get'
${ILO_SRV02} 'vm cdrom get'
${ILO_SRV03} 'vm cdrom get'

${ILO_SRV02} 'power on'
${ILO_SRV03} 'power on'
${ILO_SRV01} 'power on'


# Remove servers from known_hosts
sed -i '/10.2.1.55/d' ${HOME}/.ssh/known_hosts
sed -i '/10.2.1.56/d' ${HOME}/.ssh/known_hosts
sed -i '/10.2.1.57/d' ${HOME}/.ssh/known_hosts

# create hosts file
cat << EOF > hosts 
[nodes]
10.2.1.56 ansible_user=cloud ansible_password=cloud
10.2.1.57 ansible_user=cloud ansible_password=cloud
10.2.1.55 ansible_user=cloud ansible_password=cloud

[controller]
10.2.1.55 ansible_user=cloud ansible_password=cloud

EOF

# Create config file
# To create the password:  echo -n "your_password" | openssl passwd -6 -stdin
cat << EOF > config.yml
nodes:
  - 10.2.1.56
  - 10.2.1.57
  - 10.2.1.55

key_file: ${HOME}/.ssh/id_rsa.pub
new_password: \$6\$u83aW56dcV7L6nYu\$KVqYYN6hv50j5aNIRpFEhMl.biaMhd/xPSQzByyAVgKqICP6DiqvIe7rIUL/DxdlkYNWV1GnXInqYM09cN7ja/

EOF

# Start configuration
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts configure.yml  --extra-vars "ansible_sudo_pass=cloud"

# Remove files:
rm -f config.yml
rm -f hosts

# Start openstack deployment:
podman stop ${PODMAN_NAME} >/dev/null 2>&1
cp ${OPENSTACK_CONFIG_FILE} ../ansible/
cd ../ansible
python3 create_inventory.py config.yml
time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml 

cd ${CWD}

cat << EOF > hosts 
[nodes]
10.2.1.56 ansible_user=cloud ansible_password=cloud
10.2.1.57 ansible_user=cloud ansible_password=cloud
10.2.1.55 ansible_user=cloud ansible_password=cloud

[controller]
10.2.1.55 ansible_user=cloud ansible_password=cloud

EOF

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts get_rc_files.yml

# Copy password files to the directory
cp ../ansible/passwords.yml .


set +x