#!/bin/sh
#This is a program to install Arch/Artix on a system.

#Constants
drive=/dev/sda
driveP="$drive"
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
sgdisk --new 3:::       --typecode 3:8304 --change-name 3:"System" "$drive"    
partprobe $DRIVE #Saves
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3


#Encrypting 
# For some reason -v doesnt work.
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 luksFormat "$driveP"3
cryptsetup open "$driveP"3 system
cryptsetup close system
cryptsetup open "$driveP"3 system


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
mkfs.fat -F32 -n LIUNXEFI "$driveP"1
mkfs.btrfs -L ROOT /dev/systemgruop/root
mkfs.btrfs -L USR /dev/systemgruop/usr
mkfs.btrfs -L ETC /dev/systemgruop/etc
mkfs.btrfs -L VAR /dev/systemgruop/var
mkfs.btrfs -L SNAP /dev/systemgruop/snap
mkfs.btrfs -L HOME /dev/systemgruop/home
mkswap /dev/systemgroup/swap


#Mounting the boot system
mount -o noatime,compress=zstd:2 /dev/systemgroup/root /mnt
mkdir /mnt/{boot,usr,etc,var,snap,home}
mount -o noatime,compress=zstd:2 /dev/systemgroup/home  /home
mount -o noatime,compress=zstd:2 /dev/systemgroup/usr   /mnt/usr
mount -o noatime,compress=zstd:2 /dev/systemgroup/etc   /mnt/etc
mount -o noatime,compress=zstd:2 /dev/systemgroup/var   /mnt/var
mount -o noatime,compress=zstd:2 /dev/systemgroup/snap  /mnt/snap
mount -o noatime,compress=zstd:2 /dev/systemgroup/home  /mnt/home
mount "$driveP"1 /mnt/boot
swapon /dev/systemgroup/swap


#The system
pacstrap -i /mnt base linux-hardened linux-firmware intel-ucode lvm2
genfstab -U /mnt > /mnt/etc/fstab
cp archInstall.sh /mnt
arch-chroot /mnt









