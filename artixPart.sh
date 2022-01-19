#!/bin/sh


#Constants
drive=/dev/sda
driveP=$drive #For a nvme
cryptname=lvmsys
volname=sys


#Partions
pacman -S --noconfirm gptfdisk parted #artix only
sgdisk --zap-all "$drive"
sgdisk --mbrtogpt "$drive"
sgdisk --new 1::+512M   --typecode 1:ef00 --change-name 1:"EFI-Boot" "$drive"
sgdisk --new 2:::       --typecode 2:8304 --change-name 2:"SYSTEM"   "$drive"
partprobe $DRIVE #Saves
wipefs -af $driveP"1"
wipefs -af $driveP"2"


#Encrypting 
cryptsetup -v --type luks2 --hash sha512 luksFormat $driveP"2"
cryptsetup open $driveP"2" $cryptname
pvcreate /dev/mapper/$cryptname
vgcreate $volname /dev/mapper/$cryptname
lvcreate -L 1G $volname -n swap
lvcreate -L 1G $volname -n root
lvcreate -L 1G $volname -n etc
lvcreate -L 5G $volname -n var
lvcreate -L 9G $volname -n usr
lvcreate -L 1G $volname -n home
lvcreate -L 1G $volname -n snap


#Formatting
mkfs.fat -F32 -n LIUNXEFI $driveP"1"
mkswap /dev/$volname/swap
swapon /dev/$vouname/swap
mkfs.btrfs -q -L ROOT /dev/$volname/root
mkfs.btrfs -q -L ETC /dev/$volname/etc
mkfs.btrfs -q -L VAR /dev/$volname/var
mkfs.btrfs -q -L USR /dev/$volname/usr
mkfs.btrfs -q -L HOME /dev/$volname/home
mkfs.btrfs -q -L SNAP /dev/$volname/snap


#Mounting
mount -o noatime,nodiratime,compress=zstd:4 /dev/$volname/root /mnt
mkdir /mnt/{efi,etc,var,usr,home,snap}
mount -o noatime,nodiratime,compress=zstd:4 /dev/$volname/etc /mnt/etc
mount -o noatime,nodiratime,compress=zstd:4 /dev/$volname/var /mnt/var
mount -o noatime,nodiratime,compress=zstd:2 /dev/$volname/usr /mnt/usr
mount -o noatime,nodiratime,compress=zstd:2 /dev/$volname/home /mnt/home
mount -o noatime,nodiratime,compress=zstd:4 /dev/$volname/snap /mnt/snap
mount $driveP"1" /mnt/efi

#Entering the new system
basestrap /mnt base runit elogind-runit linux-zen linux-zen-headers linux-firmware intel-ucode 

fstabgen -U /mnt > /mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab

