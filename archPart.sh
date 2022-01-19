#!/bin/sh
#This is a program to install Arch/Artix on a system.

#Constants
drive=/dev/sda
bootP=/dev/sda1
rootP=/dev/sda2


#Clearing Current System
pacman -S --noconfirm gptfdisk
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"
sgdisk --new 1::+1G --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"       
sgdisk --new 2:::   --typecode 2:8304 --change-name 2:"System" "$drive"
partprobe $DRIVE #Saves
wipefs -af $bootP
wipefs -af $rootP


#Encrypting 
# For some reason -v doesnt work.
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 luksFormat $rootP
cryptsetup open $rootP system
cryptsetup close system
cryptsetup open $rootP system


#making LVM
pvcreate /dev/mapper/system
vgcreate systemgroup /dev/mapper/system
    #Making Logical Partions
lvcreate -L 2G systemgroup -n swap
lvcreate -L 2G systemgroup -n root
lvcreate -L 9G systemgroup -n usr
lvcreate -L 1G systemgroup -n etc
lvcreate -L 5G systemgroup -n var
lvcreate -L 1G systemgroup -n home
lvcreate -L 1G systemgroup -n snap


#Formatting
mkfs.fat -F32 -n LIUNXEFI $bootP
mkfs.btrfs -L ROOT /dev/systemgroup/root
mkfs.btrfs -L USR /dev/systemgroup/usr
mkfs.btrfs -L ETC /dev/systemgroup/etc
mkfs.btrfs -L VAR /dev/systemgroup/var
mkfs.btrfs -L SNAP /dev/systemgroup/snap
mkfs.btrfs -L HOME /dev/systemgroup/home
mkswap /dev/systemgroup/swap


#Mounting the boot system
mount -o noatime,compress=zstd:2 /dev/systemgroup/root /mnt
mkdir /mnt/{boot,usr,etc,var,snap,home}
mount -o noatime,compress=zstd:2 /dev/systemgroup/usr   /mnt/usr
mount -o noatime,compress=zstd:2 /dev/systemgroup/etc   /mnt/etc
mount -o noatime,compress=zstd:2 /dev/systemgroup/var   /mnt/var
mount -o noatime,compress=zstd:2 /dev/systemgroup/snap  /mnt/snap
mount -o noatime,compress=zstd:2 /dev/systemgroup/home  /mnt/home
mount $bootP /mnt/boot
swapon /dev/systemgroup/swap


#The system
pacstrap -i /mnt base linux-hardened linux-firmware intel-ucode lvm2
genfstab -U /mnt > /mnt/etc/fstab
cp archInstall.sh /mnt
arch-chroot /mnt









