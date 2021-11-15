#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda

#Clearing Current System
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"

#Making Drives (Change size in real run)
sgdisk --new 1::+512M --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"
sgdisk --new 2::+500M --typecode 2:8200 --change-name 2:"System-Swap" "$drive"
sgdisk --new 3::+12G --typecode 3:8304 --change-name 3:"Main-System" "$drive"
sgdisk --new 4::: --typecode 4:8300 --change-name 4:"Home-Storage" "$drive"
partprobe $DRIVE #Saves Changes. 


#Wiping Drives
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3
wipefs -af "$driveP"4

#Only encrypt what arch uses. Gentoo can read home??
#cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"3
#cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"6

#Opening System
#cryptsetup open "$driveP"3 mainSystem
#cryptsetup open "$driveP"6 homePartion

#Formatting
mkfs.vfat "$driveP"1
mkswap "$driveP"2
swapon "$driveP"2
mkfs.btrfs "$driveP"3 
mkfs.btrfs "$driveP"4

#Mounting
mount -o noatime,nodiratime,compress=zstd:2 "$driveP"3 /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "$driveP"1 /mnt/boot
mount -o noatime,nodiratime,compress=zstd:4 "$driveP"4 /mnt/home


pacstrap /mnt base linux-zen linux-zen-headers linux-firmware intel-ucode 
genfstab -U /mnt > /mnt/etc/fstab
