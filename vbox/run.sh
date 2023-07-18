#!/bin/bash
podman stop build >/dev/null 2>&1
cat << EOF > Dockerfile
FROM ubuntu
RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3 cloud-init xorriso isolinux wget git curl gpg -y
EOF

if ! podman images | grep -P 'localhost/ubuntu-auto-install\s+0.0.1'; then
    buildah bud -f Dockerfile -t ubuntu-auto-install:0.0.1
fi 
vm_list=("srv01" "srv02" "srv03")
mem_list=("8192" "8192" "4096")
cpu_list=("4" "4" "4")
rdp_port=("5001" "5002" "5003")
podman run -t -d --name build --rm  ubuntu-auto-install:0.0.1 bash
for i in ${vm_list[*]}; do
    rm ${i}.iso >/dev/null 2>&1
done

for i in {0..10}; do
    VBoxManage hostonlyif remove vboxnet${i} >/dev/null 2>/dev/null
done 

index=0
disk_dir="/home/eduardoefb/vboxdisks"
for i in ${vm_list[*]}; do
    podman cp ubuntu-20.04.6-live-server-amd64.iso build:/root/ubuntu.iso
    podman cp auto_install_configs  build:/root/
    podman cp ubuntu-autoinstall-generator.sh build:/root/ubuntu-autoinstall-generator.sh
    podman exec -it build /root/ubuntu-autoinstall-generator.sh -a -u /root/auto_install_configs/${i}.yml -s /root/ubuntu.iso -d /root/${i}.iso -c -k
    podman cp build:/root/${i}.iso ${disk_dir}/     
done
podman stop build >/dev/null 2>&1&

# Host only
VBoxManage hostonlyif create
VBoxManage hostonlyif create
VBoxManage hostonlyif create
sleep 5
VBoxManage hostonlyif ipconfig vboxnet0 --ip 172.250.0.1 --netmask 255.255.255.0
VBoxManage hostonlyif ipconfig vboxnet1 --ip 172.250.1.1 --netmask 255.255.255.0
VBoxManage hostonlyif ipconfig vboxnet2 --ip 172.250.2.1 --netmask 255.255.255.0

#sudo iptables -t nat -F

for i in ${vm_list[*]}; do    
    VBoxManage closemedium dvd {i}.iso --delete >/dev/null 2>&1
    VBoxManage createvm --name ${i} --ostype "Ubuntu_64" --register 
    VBoxManage modifyvm ${i} --memory ${mem_list[index]}
    VBoxManage modifyvm ${i} --cpus ${cpu_list[index]} 
    #VBoxManage modifyvm ${i} --nested-hw-virt on
    VBoxManage modifyvm ${i} --vrde-port ${rdp_port[index]} --vrde on
    VBoxManage createmedium disk --filename "${disk_dir}/${i}_disk1.vdi" --size 40960 --format VDI
    VBoxManage createmedium disk --filename "${disk_dir}/${i}_disk2.vdi" --size 40960 --format VDI
    VBoxManage createmedium disk --filename "${disk_dir}/${i}_disk3.vdi" --size 40960 --format VDI
    VBoxManage storagectl ${i} --name "SCSI ${i}" --add scsi
    VBoxManage storageattach ${i} --storagectl "SCSI ${i}" --port 0 --device 0 --type hdd --medium "${disk_dir}/${i}_disk1.vdi"
    VBoxManage storageattach ${i} --storagectl "SCSI ${i}" --port 1 --device 0 --type hdd --medium "${disk_dir}/${i}_disk2.vdi"
    VBoxManage storageattach ${i} --storagectl "SCSI ${i}" --port 2 --device 0 --type hdd --medium "${disk_dir}/${i}_disk3.vdi"

    VBoxManage modifyvm ${i} --nic1 hostonly --hostonlyadapter1 vboxnet0
    VBoxManage modifyvm ${i} --nic2 hostonly --hostonlyadapter2 vboxnet1
    VBoxManage modifyvm ${i} --nic3 hostonly --hostonlyadapter3 vboxnet2

    VBoxManage storagectl ${i} --name "IDE ${i}" --add ide
    
    VBoxManage storageattach ${i} --storagectl "IDE ${i}" --port 0 --device 0 --type dvddrive --medium ${disk_dir}/${i}.iso
    VBoxManage startvm ${i} --type=headless
    VBoxManage controlvm  ${i} reset
    index=$((${index}+1))
done

bash configure.sh
cd ../ansible
python3 create_inventory.py config.yml
time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml 
