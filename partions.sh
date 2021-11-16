#!/bin/sh

#Constants
drive=/dev/nvme0n1
driveP=/dev/nvme0n1p
hostname=main #CAN THIS BE UPPERCASE???
username=taha
wifiP=password
wifiU=username
mainSysName=mainSystem

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

#Generate Filesystem table
genfstab -U /mnt > /mnt/etc/fstab

#Entering the new system
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware intel-ucode 
arch-chroot /mnt /bin/bash

#Installing none essential software for basic opperation
pacman -S --noconfirm nano doas wpa_supplicant dhcpcd zsh

#Language time, etc.
ln -sf /urs/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_CA.UTF-8 UTF-8" >> locale.gen
locale-gen
echo "LANG=en_CA.UTF-8\nLANGUAGE=en_CA\nLC_ALL=c" >> /etc/locale.conf
echo $hostname >> /etc/hostname
chsh -s /bin/zsh

#internet stuff
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 "$hostname".localdomain "$hostname >> /etc/hosts
mkdir /etc/wpa_supplicant
touch /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf
echo -e "ctrl_interface=/run/wpa_supplicant\nupdate_config=1\nupdate_config\nnetwork={\n    ssid='$wifiU'\n    psk='$wifiP'\n}"> /etc/wpa_supplicant/wpa_supplicant-wlp5s0.conf

#Users and passwords
echo "ROOT THEN USERNAME PASSWORD"
passwd
useradd -m -g users -G wheel "$username"
passwd "$username"
touch /etc/doas.conf
echo "permit wheel as root" > /etc/doas.conf

#Editing FSTAB
echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab
echo "tmpfs /home/"$username"/.cache tmpfs defaults,noatime 0 0" >> /etc/fstab

#mkinitcpio
echo -e "MODULES=(btrfs)\nBINARIES=()\nFILES=()\nHOOKS=(base udev autodetect block encrypt filesystems keyboard fsck)\nCOMPRESSION='zstd'" > /etc/mkinitcpio.conf
mkinitcpio -p

#Bootloader
mkdir /boot/loader
mkdir /boot/loader/entries
touch /boot/loader/loader.conf
touch /boot/loader/entries/arch.conf

UUID3=$(blkid -s UUID -o value "$driveP"3)
echo -e 'title ArchLinux\n linux /vmlinuz-linux-zen\ninitrd /initramfs-linux-zen.img\n options rd.luks.name='$UUID3':cryptroot root=/dev/mapper/mainSystem rd.luks.options=discard rw loglevel=3' > /boot/loader/entries/arch.conf
echo -e "default arch.conf\ntimeout 5\nconsole-mode max\neditor no" >> /boot/loader/loader.conf

bootctl --path=/boot install

echo "Well This worked???"
ls
