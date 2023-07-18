#!/bin/bash
vm_list=("srv01" "srv02" "srv03")
for i in ${vm_list[*]}; do
    VBoxManage controlvm  ${i} poweroff >/dev/null 2>&1 && sleep 10
    VBoxManage unregistervm ${i} --delete
    #VBoxManage closemedium disk "${i}_disk1.vdi" --delete
    #VBoxManage closemedium disk "${i}_disk2.vdi" --delete
    #VBoxManage closemedium disk "${i}_disk3.vdi" --delete
done

#for i in {0..10]; do
#    VBoxManage hostonlyif remove vboxnet${i} >/dev/null 2>/dev/null 
#done 


rm -rf disks/*.iso
rm -rf disks/*.vdi