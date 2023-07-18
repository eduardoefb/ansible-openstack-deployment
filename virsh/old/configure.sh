#!/bin/bash

sed -i '/172.250.0.10/d' ${HOME}/.ssh/known_hosts
sed -i '/172.250.0.11/d' ${HOME}/.ssh/known_hosts
sed -i '/172.250.0.12/d' ${HOME}/.ssh/known_hosts

cat << EOF > hosts 
[nodes]
172.250.0.10 ansible_user=cloud ansible_password=cloud
172.250.0.11 ansible_user=cloud ansible_password=cloud
172.250.0.12 ansible_user=cloud ansible_password=cloud

[controller]
172.250.0.10 ansible_user=cloud ansible_password=cloud

EOF

cat << EOF > config.yml
nodes:
  - 172.250.0.10
  - 172.250.0.11
  - 172.250.0.12

key_file: ${HOME}/.ssh/id_rsa.pub
new_password: \$6\$u83aW56dcV7L6nYu\$KVqYYN6hv50j5aNIRpFEhMl.biaMhd/xPSQzByyAVgKqICP6DiqvIe7rIUL/DxdlkYNWV1GnXInqYM09cN7ja/

EOF
# To create the password:  echo -n "your_password" | openssl passwd -6 -stdin

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts configure.yml  --extra-vars "ansible_sudo_pass=cloud"




#cd ../ansible
#python3 create_inventory.py config.yml
#time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml