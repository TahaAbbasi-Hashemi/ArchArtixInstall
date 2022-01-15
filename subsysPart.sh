#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda
#Bootnames
par3=SubSys
par5=HomeSys


#Opening Partions
cryptsetup open "$driveP"5 $par3
cryptsetup open "$driveP"7 $par5


#Mounting
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/$par5 /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "$driveP"1 /mnt/boot
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/$par5 /mnt/home


#Entering the new system
pacstrap -i /mnt base linux-hardened linux-hardened-headers linux-firmware intel-ucode 
genfstab -U /mnt > /mnt/etc/fstab
cp subsysInstall.sh /mnt
arch-chroot /mnt

