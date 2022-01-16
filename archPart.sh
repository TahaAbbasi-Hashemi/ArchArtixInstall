#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda
#Boot names
par1=BootSystem
par2=MainSystem
par3=SubSystem
par4=SpareSystem
par5=HomeStorage

#Clearing Current System
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"
sgdisk --new 1::+2G     --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"       
sgdisk --new 2::+2G     --typecode 2:8200 --change-name 2:"System-Swap" "$drive"
sgdisk --new 3:::       --typecode 3:8304 --change-name 3:"root" "$drive"    
partprobe $DRIVE #Saves
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3


#Encrypting 
# For some reason -v doesnt work.
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 luksFormat /dev/sda3
cryptsetup open /dev/sda3 root


#Formatting
mkfs.fat -F32 -n LIUNXEFI "$driveP"1
mkswap "$driveP"2
swapon "$driveP"2
#mkfs.ext4  -L name "$driveP"3
mkfs.btrfs -L root /dev/mapper/root

#Checking if encryption works
cryptsetup close root
cryptsetup open "$driveP"3 root


#Mounting the boot system
mount /dev/mapper/root /mnt
mkdir /mnt/boot
mount "$driveP"1 /mnt/boot

pacstrap -i /mnt base linux-hardened linux-firmware intel-ucode
genfstab -U /mnt > /mnt/etc/fstab

cp archInstall.sh /mnt
arch-chroot /mnt

