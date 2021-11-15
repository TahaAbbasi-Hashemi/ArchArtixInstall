#!/bin/sh

#Constants
drive=/dev/nvme0n1
driveP=/dev/nvme0n1p

#Clearing Current System
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"

#Making Drives (Change size in real run)
sgdisk --new 1::+512M --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"
sgdisk --new 2::+500M --typecode 2:8200 --change-name 2:"System-Swap" "$drive"
sgdisk --new 3::+12G --typecode 3:8304 --change-name 3:"Main-System" "$drive"
sgdisk --new 4::+500M --typecode 4:8304 --change-name 4:"Sub-System" "$drive"
sgdisk --new 5::+500M --typecode 5:8304 --change-name 5:"Spare-System" "$drive"
sgdisk --new 6::: --typecode 6:8300 --change-name 6:"Home-Storage" "$drive"
partprobe $DRIVE #Saves Changes. 


#Wiping Drives
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3
wipefs -af "$driveP"4
wipefs -af "$driveP"5
wipefs -af "$driveP"6

#Only encrypt what arch uses. Gentoo can read home??
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"3
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"6

#Opening System
cryptsetup open "$driveP"3 mainSystem
cryptsetup open "$driveP"6 homePartion

#Formatting
mkfs.fat -F32 -n LIUNXEFI "$driveP"1
mkswap "$driveP"2
swapon "$driveP"2
mkfs.btrfs -L MainSystem /dev/mapper/mainSystem 
mkfs.btrfs -L HomePartion /dev/mapper/homePartion

#Mounting
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/mainSystem /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "$driveP"1 /mnt/boot
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/homePartion /mnt/home


pacstrap /mnt base linux-zen linux-zen-headers linux-firmware intel-ucode 
genfstab -U /mnt > /mnt/etc/fstab
