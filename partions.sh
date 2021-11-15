#!/bin/sh


DRIVE=/dev/nvme0n1
WIFI_PASSWORD=password
WIFI_USERNAME=username

#Clearing Current System
sgdisk --zap-all "$DRIVE"
sgdisk --mbrtogpt "$DRIVE"

#Making Drives (Change size in real run)
sgdisk --new 1::+512M --typecode 1:ef00 --change-name 1:"EFI-Boot" "$DRIVE"
sgdisk --new 2::+500M --typecode 2:8200 --change-name 1:"System-Swap" "$DRIVE"
sgdisk --new 3::+12G --typecode 3:8304 --change-name 3:"Main-System" "$DRIVE"
sgdisk --new 4::+500M --typecode 4:8304 --change-name 4:"Sub-System" "$DRIVE"
sgdisk --new 5::+500M --typecode 5:8304 --change-name 5:"Spare-System" "$DRIVE"
sgdisk --new 6::: --typecode 6:8300 --change-name 6:"Home-Storage" "$DRIVE"
partprobe $DRIVE #Saves Changes. 


#Wiping Drives
wipefs -af "$DRIVE"1
wipefs -af "$DRIVE"2
wipefs -af "$DRIVE"3
wipefs -af "$DRIVE"4
wipefs -af "$DRIVE"5
wipefs -af "$DRIVE"6

#Only encrypt what arch uses. Gentoo can read home??
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$DRIVE"3
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$DRIVE"6

#Opening System
cryptsetup open "$DRIVE"3 mainSystem
cryptsetup open "$DRIVE"6 homePartion

#Formatting
mkfs.vfat "$DRIVE"1
mkswap "$DRIVE"2
swapon "$DRIVE"2
mkfs.btrfs /dev/mapper/mainSystem 
mkfs.btrfs /dev/mapper/homePartion

#Mounting
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/mainSystem /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/homePartion /mnt/home #Setup snaps for the home directory....

#nmcli device connect USERMAME password $WIFI_PASSWORD
pacstrap /mnt base linux-zen linux-firmware intel-ucode 
genfstab -U /mnt > /mnt/etc/fstab

