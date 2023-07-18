#!/bin/bash

sed -i '/172.250.0.10/d' ${HOME}/.ssh/known_hosts
sed -i '/172.250.0.11/d' ${HOME}/.ssh/known_hosts
sed -i '/172.250.0.12/d' ${HOME}/.ssh/known_hosts

cat << EOF > hosts 
[nodes]
172.250.0.10 ansible_user=cloud ansible_password=cloud
172.250.0.11 ansible_user=cloud ansible_password=cloud
172.250.0.12 ansible_user=cloud ansible_password=cloud

EOF

cat << EOF > config.yml
nodes:
  - 172.250.0.10
  - 172.250.0.11
  - 172.250.0.12

key_file: ${HOME}/.ssh/id_rsa.pub
EOF

if ! ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts configure.yml  --extra-vars "ansible_sudo_pass=cloud"; then 
exit 1
fi




#cd ../ansible
#python3 create_inventory.py config.yml
#time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml