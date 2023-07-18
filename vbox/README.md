##### Create the custom iso files:

Download ubuntu iso file `ubuntu-20.04.6-live-server-amd64.iso`

And run the script:
```bash 
bash run.sh
```

After that, execute the configure script:
```bash
bash configure.sh
```
Install openstack:
```shell
cd ../ansible
python3 create_inventory.py config.yml
time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts create.yml 
```

```shell
podman stop build&
cat << EOF > Dockerfile
FROM ubuntu
RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3 cloud-init xorriso isolinux wget git curl gpg -y
EOF

buildah bud -f Dockerfile -t ubuntu-auto-install:0.0.1
rm srv01.iso
podman run -t -d --name build --rm  ubuntu-auto-install:0.0.1 bash
podman cp ubuntu-20.04.6-live-server-amd64.iso build:/root/ubuntu.iso
podman cp auto_install_configs  build:/root/
podman cp ubuntu-autoinstall-generator.sh build:/root/ubuntu-autoinstall-generator.sh
podman exec -it build /root/ubuntu-autoinstall-generator.sh -a -u /root/auto_install_configs/srv01.yml -s /root/ubuntu.iso -d /root/srv01.iso -c -k
podman cp build:/root/srv01.iso .
podman stop build&

```


##### Create vms:

```shell
VBoxManage controlvm  srv01 poweroff
VBoxManage unregistervm "srv01" --delete
VBoxManage closemedium disk "srv01Disk1.vdi" --delete
VBoxManage closemedium disk "srv01Disk2.vdi" --delete
VBoxManage closemedium disk "srv01Disk3.vdi" --delete


VBoxManage createvm --name "srv01" --ostype "Ubuntu_64" --register
VBoxManage modifyvm "srv01" --memory 8192
VBoxManage createmedium disk --filename "srv01Disk1.vdi" --size 40960 --format VDI
VBoxManage createmedium disk --filename "srv01Disk2.vdi" --size 40960 --format VDI
VBoxManage createmedium disk --filename "srv01Disk3.vdi" --size 40960 --format VDI
VBoxManage storagectl "srv01" --name "SCSI srv01" --add scsi
VBoxManage storageattach "srv01" --storagectl "SCSI srv01" --port 0 --device 0 --type hdd --medium "srv01Disk1.vdi"
VBoxManage storageattach "srv01" --storagectl "SCSI srv01" --port 1 --device 0 --type hdd --medium "srv01Disk2.vdi"
VBoxManage storageattach "srv01" --storagectl "SCSI srv01" --port 2 --device 0 --type hdd --medium "srv01Disk3.vdi"

VBoxManage modifyvm "srv01" --nic1 hostonly --hostonlyadapter1 vboxnet0
VBoxManage modifyvm "srv01" --nic2 hostonly --hostonlyadapter2 vboxnet1
VBoxManage modifyvm "srv01" --nic3 hostonly --hostonlyadapter3 vboxnet2

VBoxManage storagectl "srv01" --name "IDE srv01" --add ide
VBoxManage storageattach "srv01" --storagectl "IDE srv01" --port 0 --device 0 --type dvddrive --medium srv01.iso
VBoxManage startvm srv01
```