#!/bin/bash

clear
##echo "Creation of partition of disk"
##echo "If you see for first time: Command (m for help):, please press n"

##echo "Enter default propositions"
##echo "If you see for second time: Command (m for help):, please press w"

read -p "Enter Physical Volume name sd_(example: sdb, sdc, ...; 'sda' was not expected): " sdn
##sudo fdisk "/dev/$sdn"

read -p "Enter Volume Group name (' ' and '-' were not authorized): " vgname

read -p "Enter the Logical Volume name (example: volume1): " lvname

read -p "Enter the Capacity of the disk : (example: 2.0 if it had 2.0Go): " size

echo $sdn, $vgname, $size

sudo pvcreate /dev/$sdn
sudo vgcreate $vgname /dev/$sdn
sudo lvcreate -L $size"G" -n $lvname $vgname

cd ~/..
cd /dev/mapper/

sudo mkfs.ext4 "/dev/mapper/$vgname-$lvname"
sudo mount "/dev/mapper/$vgname-$lvname /var/backups"
sudo df -kh

cd ~/..
cd /etc

echo "Please write 'nano fstab'"
echo "At the last line, write '/dev/mapper/$vgname-$lvname /var/backups ext4 defaults 0 0'"
echo "To leave nano, press 'Ctrl+S' to save, then press 'Ctrl+X' to exit"
