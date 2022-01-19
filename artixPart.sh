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
sgdisk --new 1::+512M   --typecode 1:ef00 --change-name 1:"BOOT" "$drive"
sgdisk --new 2:::       --typecode 2:8304 --change-name 2:"SYS"   "$drive"
partprobe $drive #Saves
wipefs -af $driveP"1"
wipefs -af $driveP"2"


#Encrypting 
echo -e "\n \n \nENCRYPTING"
sleep 10
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
echo -e "\n \n \nFORMATING"
sleep 10
mkfs.fat -F32 -n LIUNXEFI $driveP"1"
mkswap /dev/mapper/$volname-swap
swapon /dev/mapper/$volname-swap

mkfs.btrfs -q -L ROOT /dev/mapper/$volname-root
mkfs.btrfs -q -L ETC /dev/mapper/$volname-etc
mkfs.btrfs -q -L VAR /dev/mapper/$volname-var
mkfs.btrfs -q -L USR /dev/mapper/$volname-usr
mkfs.btrfs -q -L HOME /dev/mapper/$volname-home
mkfs.btrfs -q -L SNAP /dev/mapper/$volname-snap


#Mounting
echo -e "\n\n\nMOUNTING"
sleep 10
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/$volname-root /mnt
mkdir /mnt/{boot,etc,var,usr,home,snap}
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/$volname-etc /mnt/etc
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/$volname-var /mnt/var
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/$volname-usr /mnt/usr
mount -o noatime,nodiratime,compress=zstd:2 /dev/mapper/$volname-home /mnt/home
mount -o noatime,nodiratime,compress=zstd:4 /dev/mapper/$volname-snap /mnt/snap
mount $driveP"1" /mnt/boot

#Entering the new system
basestrap -i /mnt base btrfs-progs elogind-runit linux-hardened linux-hardened-headers linux-firmware intel-ucode 
fstabgen -U /mnt > /mnt/etc/fstab
echo "tmpfs	/tmp	tmpfs	rw,nosuid,noatime,nodev	0 0" >> /mnt/etc/fstab
cp archInstall.sh /mnt
artix-chroot /mnt /bin/bash
