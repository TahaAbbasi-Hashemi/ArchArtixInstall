#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda
#Bootnames
par2=MainSys
par5=HomeSys


#Opening Partions
cryptsetup open "$driveP"4 $par2
cryptsetup open "$driveP"7 $par5


#Mounting
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/$par2 /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "$driveP"1 /mnt/boot
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/$par5 /mnt/home


#Entering the new system
basestrap /mnt base runit elogind-runit linux-zen linux-zen-headers linux-firmware intel-ucode 
fstabgen -U /mnt > /mnt/etc/fstab
cp mainsysInstall.sh /mnt
artix-chroot /mnt

