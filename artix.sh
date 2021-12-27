#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda
mainSysName=mainSystem
hostname=mainsystem
username=taha
wifiP=password
wifiU=username

#For artix only
pacman -S --noconfirm gptfdisk #To get sgdisk

#Clearing Current System
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"
sgdisk --new 1::+512M   --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"       #Change to 1gb
sgdisk --new 2::+500M   --typecode 2:8200 --change-name 2:"System-Swap" "$drive"    #Change to 30gb
sgdisk --new 3::+12G    --typecode 3:8304 --change-name 3:"Main-System" "$drive"    #Change to 50gb
sgdisk --new 4::+500M   --typecode 4:8304 --change-name 4:"Sub-System" "$drive"     #Change to 50gb
sgdisk --new 5::+500M   --typecode 5:8304 --change-name 5:"Spare-System" "$drive"   #Change to 50gb
sgdisk --new 6:::       --typecode 6:8300 --change-name 6:"Home-Storage" "$drive"
partprobe $DRIVE #Saves
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3
wipefs -af "$driveP"4
wipefs -af "$driveP"5
wipefs -af "$driveP"6


#Encrypting 
# For some reason -v doesnt work.
cryptsetup --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"3
cryptsetup --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"6
cryptsetup open "$driveP"3 mainSystem
cryptsetup open "$driveP"6 homePartion


#Formatting
mkfs.fat -F32 -n LIUNXEFI "$driveP"1
mkswap "$driveP"2
swapon "$driveP"2
mkfs.btrfs -L MainSystem /dev/mapper/mainSystem 
mkfs.btrfs -L HomePartion /dev/mapper/homePartion
#mkfs.btrfs -L MainSystem "$driveP"3
#mkfs.btrfs -L HomePartion "$driveP"6


#BTRFS subsystems
#mount /dev/mapper/homePartion /mnt
#btrfs subvolume create /mnt/@development
#btrfs subvolume create /mnt/@configuration
#btrfs subvolume create /mnt/@teaching
#btrfs subvolume create /mnt/@school
#btrfs subvolume create /mnt/@research
#btrfs subvolume create /mnt/@documents
#umount /mnt


#Mounting
#mount -o noatime,nodiratime,compress=zstd:2 "$driveP"3 /mnt
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/mainSystem /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount "$driveP"1 /mnt/boot
#mount -o noatime,nodiratime,compress=zstd:4 "$driveP"6 /mnt/home
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/homePartion /mnt/home


#mount -o noatime,nodiratime,compress=zstd:4,subvol=@development     /dev/mapper/homePartion /mnt/home/development
#mount -o noatime,nodiratime,compress=zstd:4,subvol=@configuration   /dev/mapper/homePartion /mnt/home/configuration
#mount -o noatime,nodiratime,compress=zstd:4,subvol=@teaching        /dev/mapper/homePartion /mnt/home/teaching
#mount -o noatime,nodiratime,compress=zstd:4,subvol=@school          /dev/mapper/homePartion /mnt/home/school
#mount -o noatime,nodiratime,compress=zstd:4,subvol=@research        /dev/mapper/homePartion /mnt/home/research
#mount -o noatime,nodiratime,compress=zstd:4,subvol=@documents       /dev/mapper/homePartion /mnt/home/documents


#Entering the new system
basestrap /mnt base runit elogind-runit linux-zen linux-zen-headers linux-firmware intel-ucode 
fstabgen -U /mnt > /mnt/etc/fstab
cp artixUser.sh /mnt
#artix-chroot /mnt

