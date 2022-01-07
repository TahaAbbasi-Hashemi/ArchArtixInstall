#!/bin/sh

#Constants
drive=/dev/sda
driveP=/dev/sda
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
sgdisk --new 2::+2G    --typecode 2:8200 --change-name 2:"System-Swap" "$drive"
sgdisk --new 3::+8G     --typecode 3:8304 --change-name 3:"$par1" "$drive"    
sgdisk --new 4::+25G    --typecode 4:8304 --change-name 4:"$par2" "$drive"     
sgdisk --new 5::+25G    --typecode 5:8304 --change-name 5:"$par3" "$drive"   
sgdisk --new 6::+25G    --typecode 6:8304 --change-name 6:"$par4" "$drive"
sgdisk --new 7:::       --typecode 7:8300 --change-name 7:"$par5" "$drive"
partprobe $DRIVE #Saves
wipefs -af "$driveP"1
wipefs -af "$driveP"2
wipefs -af "$driveP"3
wipefs -af "$driveP"4
wipefs -af "$driveP"5
wipefs -af "$driveP"6
wipefs -af "$driveP"7


#Encrypting 
# For some reason -v doesnt work.
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"4
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"5
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"6
cryptsetup -v --iter-time 5000 --type luks2 --hash sha512 --use-random luksFormat "$driveP"7
cryptsetup open "$driveP"4 $par1
cryptsetup open "$driveP"5 $par2
cryptsetup open "$driveP"6 $par3
cryptsetup open "$driveP"7 $par4


#Formatting
mkfs.fat -F32 -n LIUNXEFI "$driveP"1
mkswap "$driveP"2
swapon "$driveP"2
mkfs.ext4 "$driveP"3
mkfs.btrfs -L $par1 /dev/mapper/$par1
mkfs.btrfs -L $par2 /dev/mapper/$par2
mkfs.btrfs -L $par3 /dev/mapper/$par3
mkfs.btrfs -L $par4 /dev/mapper/$par4

#Adding home spots
mount /dev/mapper/$par4 /mnt
mkdir /mnt/taha
mkdir /mnt/taha/{configuration,development,teaching,school,research,documents}
umount /mnt

#Checking if encryption works
cryptsetup close $par1
cryptsetup close $par2
cryptsetup close $par3
cryptsetup close $par4


#Mountint the boot system
mount "$driveP"3 /mnt
mkdir /mnt/boot
mount "$driveP"1 /mnt/boot

pacstrap /mnt base linux linux-headers linux-firmware intel-ucode
genfstab -U /mnt > /mnt/etc/fstab

cp bootsysInstall.sh /mnt
arch-chroot /mnt

