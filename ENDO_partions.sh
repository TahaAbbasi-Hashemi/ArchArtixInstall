#!/bin/sh

###Test to make sure key works


#Constants
drive=/dev/sda
driveP=/dev/sda
hostname=main #CAN THIS BE UPPERCASE???
username=endo
mainSysName=System

#Clearing Current System
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"

#Making Drives (Change size in real run)
sgdisk --new 1::+512M --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"
sgdisk --new 2::+10G --typecode 2:8200 --change-name 2:"System-Swap" "$drive"
sgdisk --new 3::: --typecode 3:8300 --change-name 3:"System" "$drive"
partprobe $DRIVE #Saves Changes. 


#Wiping Drives
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3

#Formatting
mkfs.fat -F32 -n LIUNXEFI "$driveP"1
mkswap "$driveP"2
swapon "$driveP"2
mkfs.ext4 "$driveP"3


#Mounting
mount "$driveP"3 /mnt
mkdir /mnt/boot
mount "$driveP"1 /mnt/boot

#Generate Filesystem table
#genfstab -U /mnt > /mnt/etc/fstab

#Entering the new system
#pacstrap /mnt base linux-zen linux-zen-headers linux-firmware intel-ucode 

#Getting ready for stage two
#cp installer.sh /mnt
#cp user.sh /mnt
#arch-chroot /mnt
