#!/bin/bash

cd /root/
if [ -f ubuntu-autoinstall.iso ]; then rm -f ubuntu-autoinstall.iso; fi
if [ -d BOOT ]; then rm -rf BOOT; fi
if [ -d source-files ]; then rm -rf source-files; fi
mkdir source-files
7z -y x ubuntu.iso -osource-files
cd source-files
mv '[BOOT]' ../BOOT

cat << EOF > /tmp/grub.cfg
menuentry "Autoinstall Ubuntu Server" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet autoinstall ds=nocloud\;s=/cdrom/server/  ---
    initrd  /casper/initrd
}

EOF

cat boot/grub/grub.cfg >> /tmp/grub.cfg
mv /tmp/grub.cfg boot/grub/grub.cfg
mkdir server
touch server/meta-data
cp /root/user-data server/user-data
cd /root/
echo 
echo xorriso > create.sh
xorriso -indev ubuntu.iso -report_el_torito as_mkisofs >> create.sh
cd source-files

xorriso -as mkisofs -r \
  -V 'Ubuntu 22.04 LTS AUTO (EFIBIOS)' \
  -o ../ubuntu-autoinstall.iso \
  --grub2-mbr ../BOOT/1-Boot-NoEmul.img \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b ../BOOT/2-Boot-NoEmul.img \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c '/boot.catalog' \
  -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:::' \
  -no-emul-boot \
  .  

